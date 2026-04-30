package app.dropweb.services

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.IpPrefix
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.os.PowerManager
import android.util.Log
import androidbind.Androidbind
import app.dropweb.MainActivity
import app.dropweb.ParazitXRelayController
import app.dropweb.R
import java.net.InetAddress

/**
 * Standalone VpnService for ParazitX mode.
 *
 * This service runs in a dedicated `:parazitx` process (see AndroidManifest)
 * so Android's Foreground Service policy cannot freeze the librelay child.
 * MainActivity lives in the main process — if the user backgrounds the app,
 * Android's activity manager aggressively throttles main-process children,
 * which killed relay's watchdog and silently tore down VK calls.
 *
 * Ownership (critical):
 *   1. [ParazitXRelayController.start] is invoked from THIS service, so the
 *      spawned relay inherits the `:parazitx` cgroup and stays alive while
 *      the FGS is alive.
 *   2. tun2socks is started AFTER relay reports [TunnelStatus.TUNNEL_CONNECTED].
 *   3. Statuses are broadcast via [BROADCAST_STATUS] to the main process so
 *      MainActivity can pipe them to the Flutter EventChannel.
 *
 * tun config: 0.0.0.0/0 route, excludes our own package so relay's signaling
 * WebSocket reaches VK SFU through the underlying network (not through tun
 * -> self loop, which resets within seconds).
 */
class ParazitXVpnService : VpnService() {

    companion object {
        private const val TAG = "ParazitXVpn"
        private const val CHANNEL_ID = "parazitx_vpn"
        private const val ACTION_CHANNEL_ID = "parazitx_action"
        private const val NOTIFICATION_ID = 0x1789
        private const val ACTION_NOTIFICATION_ID = NOTIFICATION_ID + 1

        // MTU bounds for the tun. 576 is the IPv4 minimum guaranteed by
        // RFC 791; 1500 is the standard Ethernet MTU. Anything outside
        // this range is rejected and replaced with DEFAULT_MTU.
        const val DEFAULT_MTU = 1280
        private const val MIN_MTU = 576
        private const val MAX_MTU = 1500

        private const val VPN_ADDRESS = "172.19.0.1"
        private const val VPN_PREFIX = 30
        private const val VPN_DNS = "1.1.1.1"
        private const val VPN_DNS_FALLBACK = "8.8.8.8"

        const val EXTRA_JOIN_LINK = "join_link"
        const val EXTRA_SOCKS_PORT = "socks_port"
        const val EXTRA_MTU = "mtu"
        const val ACTION_STOP = "app.dropweb.parazitx.STOP"
        const val ACTION_QUERY_STATUS = "app.dropweb.parazitx.QUERY_STATUS"

        /**
         * Clamp an incoming MTU to [MIN_MTU]..[MAX_MTU]; out-of-range
         * (including 0/negative) falls back to [DEFAULT_MTU]. Logs the
         * outcome so on-device debugging can see what actually hit
         * VpnService.Builder / tun2socks.
         */
        fun sanitizeMtu(requested: Int): Int {
            val safe = if (requested in MIN_MTU..MAX_MTU) requested else DEFAULT_MTU
            if (safe != requested) {
                Log.w(
                    TAG,
                    "sanitizeMtu: requested=$requested out of range " +
                        "[$MIN_MTU..$MAX_MTU], using $safe",
                )
            }
            return safe
        }

        /**
         * Captcha auto-solve in HeadlessInAppWebView stalls when the app is
         * backgrounded (Android throttles JS in hidden webviews). Flutter
         * fires this broadcast after a short timeout so the user sees a
         * high-priority notification → tap → app foreground → JS resumes →
         * captcha solves → [ACTION_CAPTCHA_SOLVED] dismisses the notification.
         */
        const val ACTION_CAPTCHA_TIMEOUT = "app.dropweb.parazitx.CAPTCHA_TIMEOUT"
        const val ACTION_CAPTCHA_SOLVED = "app.dropweb.parazitx.CAPTCHA_SOLVED"

        /** Cross-process broadcast for status events. */
        const val BROADCAST_STATUS = "app.dropweb.parazitx.STATUS_BROADCAST"
        const val EXTRA_STATUS = "status"

        const val BROADCAST_LOG = "app.dropweb.parazitx.LOG_BROADCAST"
        const val EXTRA_LOG_LINE = "log_line"

        @Volatile
        var isRunning: Boolean = false
            private set
    }

    private var tunFd: ParcelFileDescriptor? = null
    private var tun2socksThread: Thread? = null
    @Volatile private var tun2socksStarted: Boolean = false
    @Volatile private var currentSocksPort: Int = 1080
    @Volatile private var currentMtu: Int = DEFAULT_MTU
    @Volatile private var currentStatus: String = "disconnected"
    @Volatile private var currentJoinLink: String = ""

    private var queryReceiver: BroadcastReceiver? = null
    private var captchaReceiver: BroadcastReceiver? = null
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onCreate() {
        super.onCreate()
        ensureNotificationChannels()
        // Listen for status re-query from main process (e.g. app reopened
        // while VPN still running — UI needs to bootstrap its state).
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context, intent: Intent) {
                broadcastStatus(currentStatus)
            }
        }
        val filter = IntentFilter(ACTION_QUERY_STATUS)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(receiver, filter)
        }
        queryReceiver = receiver

        val captchaR = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context, intent: Intent) {
                when (intent.action) {
                    ACTION_CAPTCHA_TIMEOUT -> showActionRequiredNotification()
                    ACTION_CAPTCHA_SOLVED -> dismissActionRequiredNotification()
                }
            }
        }
        val captchaFilter = IntentFilter().apply {
            addAction(ACTION_CAPTCHA_TIMEOUT)
            addAction(ACTION_CAPTCHA_SOLVED)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(captchaR, captchaFilter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(captchaR, captchaFilter)
        }
        captchaReceiver = captchaR
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopSelfClean()
                return START_NOT_STICKY
            }
        }

        val joinLink = intent?.getStringExtra(EXTRA_JOIN_LINK).orEmpty()
        val port = intent?.getIntExtra(EXTRA_SOCKS_PORT, 1080) ?: 1080
        val rawMtu = intent?.getIntExtra(EXTRA_MTU, DEFAULT_MTU) ?: DEFAULT_MTU
        val mtu = sanitizeMtu(rawMtu)

        if (joinLink.isEmpty()) {
            Log.e(TAG, "onStartCommand: missing joinLink")
            stopSelf()
            return START_NOT_STICKY
        }

        currentSocksPort = port
        currentMtu = mtu
        currentJoinLink = joinLink

        Log.i(TAG, "onStartCommand: socksPort=$port mtu=$mtu (raw=$rawMtu)")

        // Foreground notification MUST be posted before any long work,
        // otherwise startForegroundService → no startForeground within 5s
        // crashes the process.
        startForegroundNotification()

        // Acquire WakeLock to prevent CPU sleep while tunnel is active
        if (wakeLock == null) {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "ParazitX::Tunnel")
            wakeLock?.acquire()
        }

        if (isRunning) {
            // Already running — this is a rotation: re-AUTH with new joinLink.
            Log.i(TAG, "onStartCommand: already running, rotating joinLink")
            ParazitXRelayController.start(this, port, joinLink)
            return START_STICKY
        }

        isRunning = true
        updateStatus("CONNECTING")

        // Wire status listener BEFORE starting relay so we don't miss
        // early STATUS: lines.
        ParazitXRelayController.statusListener = { status ->
            onRelayStatus(status)
        }
        ParazitXRelayController.logListener = { line ->
            broadcastLog(line)
        }

        val err = ParazitXRelayController.start(this, port, joinLink)
        if (err != null) {
            Log.e(TAG, "relay start failed: $err")
            updateStatus("ERROR:$err")
            stopSelfClean()
            return START_NOT_STICKY
        }

        return START_STICKY
    }

    private fun onRelayStatus(status: String) {
        updateStatus(status)

        // Bring up tun2socks once relay signals the VK tunnel is ready.
        if ((status == "TUNNEL_CONNECTED" || status == "TUNNEL_ACTIVE") &&
            !tun2socksStarted
        ) {
            val started = establishTunAndStartTun2Socks(currentSocksPort, currentMtu)
            if (!started) {
                updateStatus("ERROR:establish failed")
                stopSelfClean()
            }
        }

        // Relay lost the VK call → tear everything down. Dart-layer
        // reconnect logic will re-activate.
        if (status == "TUNNEL_LOST" || status.startsWith("ERROR:")) {
            stopSelfClean()
        }
    }

    private fun applyAllowedRoutes(b: Builder) {
        // Split tunneling: 0.0.0.0/0 minus 127.0.0.0/8 expressed as 8 prefixes.
        // This excludes localhost from VPN so WebView can reach captcha proxy.
        // Note: excludeRoute() on API 33+ was tested but caused establish() to fail
        // on some devices (Android 16), so we use split routes universally.
        listOf(
            "0.0.0.0" to 2,     // 0.0.0.0 - 63.255.255.255
            "64.0.0.0" to 3,    // 64.0.0.0 - 95.255.255.255
            "96.0.0.0" to 4,    // 96.0.0.0 - 111.255.255.255
            "112.0.0.0" to 5,   // 112.0.0.0 - 119.255.255.255
            "120.0.0.0" to 6,   // 120.0.0.0 - 123.255.255.255
            "124.0.0.0" to 7,   // 124.0.0.0 - 125.255.255.255
            "126.0.0.0" to 8,   // 126.0.0.0 - 126.255.255.255
            "128.0.0.0" to 1,   // 128.0.0.0 - 255.255.255.255
        ).forEach { (addr, prefix) ->
            b.addRoute(addr, prefix)
        }
    }

    private fun establishTunAndStartTun2Socks(socksPort: Int, mtu: Int): Boolean {
        val (user, pass) = ParazitXRelayController.getSocksCredentials()
        if (user.isEmpty() || pass.isEmpty()) {
            Log.e(TAG, "establish: missing SOCKS credentials")
            return false
        }

        val effectiveMtu = sanitizeMtu(mtu)

        val fd: Int
        try {
            val builder = Builder()
                .setSession("ParazitX")
                .setMtu(effectiveMtu)
                .addAddress(VPN_ADDRESS, VPN_PREFIX)
                .addDnsServer(VPN_DNS)
                .addDnsServer(VPN_DNS_FALLBACK)
                .setBlocking(false)

            // Exclude localhost from VPN routing so WebView can reach local captcha proxy
            applyAllowedRoutes(builder)

            // Self-exclusion: librelay's signaling WebSocket must escape
            // tun via the underlying network. Without this, a self-loop
            // forms through SOCKS5 and VK resets the peer within seconds.
            val vpnExcludedPackages = listOf(
                packageName,
            )

            vpnExcludedPackages.forEach { pkg ->
                try {
                    builder.addDisallowedApplication(pkg)
                } catch (e: PackageManager.NameNotFoundException) {
                    // Package not installed on this device — skip
                } catch (e: Exception) {
                    Log.w(TAG, "addDisallowedApplication($pkg) failed", e)
                }
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                builder.setMetered(false)
            }

            val pfd = builder.establish()
            if (pfd == null) {
                Log.e(TAG, "VPN establish failed - check routes configuration")
                return false
            }
            tunFd = pfd
            fd = pfd.detachFd()
        } catch (e: Exception) {
            Log.e(TAG, "VPN establish failed - check routes configuration", e)
            return false
        }

        Log.i(
            TAG,
            "tun established fd=$fd mtu=$effectiveMtu, " +
                "starting tun2socks → 127.0.0.1:$socksPort",
        )

        tun2socksThread = Thread({
            try {
                Androidbind.startTun2Socks(
                    fd.toLong(),
                    effectiveMtu.toLong(),
                    socksPort.toLong(),
                    user,
                    pass,
                )
                Log.i(TAG, "tun2socks returned (goroutines keep running in background)")
            } catch (e: Exception) {
                Log.e(TAG, "tun2socks threw", e)
                stopSelfClean()
            }
        }, "parazitx-tun2socks").also { it.start() }

        tun2socksStarted = true
        return true
    }

    private fun updateStatus(s: String) {
        currentStatus = s
        broadcastStatus(s)
    }

    private fun broadcastStatus(s: String) {
        val i = Intent(BROADCAST_STATUS)
            .setPackage(packageName)
            .putExtra(EXTRA_STATUS, s)
        sendBroadcast(i)
    }

    private fun broadcastLog(line: String) {
        val i = Intent(BROADCAST_LOG)
            .setPackage(packageName)
            .putExtra(EXTRA_LOG_LINE, line)
        sendBroadcast(i)
    }

    private fun stopSelfClean() {
        dismissActionRequiredNotification()
        if (!isRunning && tunFd == null && !tun2socksStarted) {
            stopForegroundCompat()
            stopSelf()
            return
        }
        isRunning = false

        try {
            ParazitXRelayController.statusListener = null
            ParazitXRelayController.logListener = null
            ParazitXRelayController.stop()
        } catch (e: Exception) {
            Log.e(TAG, "relay stop threw", e)
        }

        if (tun2socksStarted) {
            try {
                Androidbind.stopTun2Socks()
            } catch (e: Exception) {
                Log.e(TAG, "stopTun2Socks threw", e)
            }
            tun2socksThread?.interrupt()
            tun2socksThread = null
            tun2socksStarted = false
        }

        try {
            tunFd?.close()
        } catch (e: Exception) {
            Log.e(TAG, "tunFd close threw", e)
        }
        tunFd = null

        currentStatus = "disconnected"
        broadcastStatus("disconnected")

        wakeLock?.let {
            if (it.isHeld) it.release()
        }
        wakeLock = null

        stopForegroundCompat()
        stopSelf()
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    override fun onRevoke() {
        Log.i(TAG, "onRevoke — system revoked VPN")
        stopSelfClean()
        super.onRevoke()
    }

    override fun onDestroy() {
        try {
            queryReceiver?.let { unregisterReceiver(it) }
        } catch (_: Exception) {}
        queryReceiver = null
        try {
            captchaReceiver?.let { unregisterReceiver(it) }
        } catch (_: Exception) {}
        captchaReceiver = null
        dismissActionRequiredNotification()
        stopSelfClean()
        super.onDestroy()
    }

    private fun ensureNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(NotificationManager::class.java) ?: return
        if (nm.getNotificationChannel(CHANNEL_ID) == null) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "ParazitX tunnel",
                NotificationManager.IMPORTANCE_LOW,
            ).apply { setShowBadge(false) }
            nm.createNotificationChannel(channel)
        }
        if (nm.getNotificationChannel(ACTION_CHANNEL_ID) == null) {
            val actionChannel = NotificationChannel(
                ACTION_CHANNEL_ID,
                "Требуется действие",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Уведомления когда нужно подтвердить соединение"
                enableVibration(true)
                enableLights(true)
                setShowBadge(true)
            }
            nm.createNotificationChannel(actionChannel)
        }
    }

    private fun showActionRequiredNotification() {
        ensureNotificationChannels()
        val openIntent = PendingIntent.getActivity(
            this,
            2,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val builder = Notification.Builder(this, ACTION_CHANNEL_ID)
            .setContentTitle("ParazitX: требуется действие")
            .setContentText("Нажмите чтобы продолжить соединение")
            .setSmallIcon(R.mipmap.ic_launcher_foreground)
            .setContentIntent(openIntent)
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_CALL)
            // fullScreenIntent wakes the user even on locked screen
            // (treated like an incoming call). Requires
            // USE_FULL_SCREEN_INTENT permission in AndroidManifest.
            .setFullScreenIntent(openIntent, true)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            @Suppress("DEPRECATION")
            builder.setPriority(Notification.PRIORITY_HIGH)
        }
        val nm = getSystemService(NotificationManager::class.java)
        nm?.notify(ACTION_NOTIFICATION_ID, builder.build())
    }

    private fun dismissActionRequiredNotification() {
        val nm = getSystemService(NotificationManager::class.java)
        nm?.cancel(ACTION_NOTIFICATION_ID)
    }

    private fun startForegroundNotification() {
        ensureNotificationChannels()
        val openIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val stopIntent = PendingIntent.getService(
            this,
            1,
            Intent(this, ParazitXVpnService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val notification: Notification = Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("ParazitX активен")
            .setContentText("Трафик идёт через VK")
            .setSmallIcon(R.mipmap.ic_launcher_foreground)
            .setContentIntent(openIntent)
            .addAction(
                Notification.Action.Builder(
                    null,
                    "Отключить",
                    stopIntent,
                ).build(),
            )
            .setOngoing(true)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }
}

/**
 * Helpers for the main process to talk to [ParazitXVpnService] cleanly.
 * All relay control lives inside the service now — callers only hand it
 * a [joinLink] + SOCKS port.
 */
object ParazitXVpnController {
    private const val TAG = "ParazitXVpnCtl"

    /**
     * Starts the VPN if already authorized. Returns true on start, false if
     * the user hasn't authorized VPN yet — caller must then run
     * [VpnService.prepare] in an Activity context.
     */
    fun start(
        ctx: Context,
        socksPort: Int,
        joinLink: String,
        mtu: Int = ParazitXVpnService.DEFAULT_MTU,
    ): Boolean {
        if (VpnService.prepare(ctx) != null) {
            Log.w(TAG, "VPN not prepared — caller must show consent dialog")
            return false
        }
        val intent = Intent(ctx, ParazitXVpnService::class.java)
            .putExtra(ParazitXVpnService.EXTRA_JOIN_LINK, joinLink)
            .putExtra(ParazitXVpnService.EXTRA_SOCKS_PORT, socksPort)
            .putExtra(ParazitXVpnService.EXTRA_MTU, mtu)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ctx.startForegroundService(intent)
        } else {
            ctx.startService(intent)
        }
        return true
    }

    fun stop(ctx: Context) {
        val intent = Intent(ctx, ParazitXVpnService::class.java)
            .setAction(ParazitXVpnService.ACTION_STOP)
        ctx.startService(intent)
    }

    /**
     * Ask the service (in `:parazitx`) to rebroadcast its current status.
     * Used by MainActivity after a cold start to bootstrap the UI when
     * the VPN was already running.
     */
    fun queryStatus(ctx: Context) {
        val intent = Intent(ParazitXVpnService.ACTION_QUERY_STATUS)
            .setPackage(ctx.packageName)
        ctx.sendBroadcast(intent)
    }

    val isRunning: Boolean get() = ParazitXVpnService.isRunning
}
