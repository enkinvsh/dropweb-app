package app.dropweb.services

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import androidbind.Androidbind
import app.dropweb.MainActivity
import app.dropweb.ParazitXRelayController
import app.dropweb.R

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
        private const val NOTIFICATION_ID = 0x1789
        private const val VPN_MTU = 1500
        private const val VPN_ADDRESS = "172.19.0.1"
        private const val VPN_PREFIX = 30
        private const val VPN_DNS = "1.1.1.1"
        private const val VPN_DNS_FALLBACK = "8.8.8.8"

        const val EXTRA_JOIN_LINK = "join_link"
        const val EXTRA_SOCKS_PORT = "socks_port"
        const val ACTION_STOP = "app.dropweb.parazitx.STOP"
        const val ACTION_QUERY_STATUS = "app.dropweb.parazitx.QUERY_STATUS"

        /** Cross-process broadcast for status events. */
        const val BROADCAST_STATUS = "app.dropweb.parazitx.STATUS_BROADCAST"
        const val EXTRA_STATUS = "status"

        @Volatile
        var isRunning: Boolean = false
            private set
    }

    private var tunFd: ParcelFileDescriptor? = null
    private var tun2socksThread: Thread? = null
    @Volatile private var tun2socksStarted: Boolean = false
    @Volatile private var currentSocksPort: Int = 1080
    @Volatile private var currentStatus: String = "disconnected"
    @Volatile private var currentJoinLink: String = ""

    private var queryReceiver: BroadcastReceiver? = null

    override fun onCreate() {
        super.onCreate()
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

        if (joinLink.isEmpty()) {
            Log.e(TAG, "onStartCommand: missing joinLink")
            stopSelf()
            return START_NOT_STICKY
        }

        currentSocksPort = port
        currentJoinLink = joinLink

        // Foreground notification MUST be posted before any long work,
        // otherwise startForegroundService → no startForeground within 5s
        // crashes the process.
        startForegroundNotification()

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
            val started = establishTunAndStartTun2Socks(currentSocksPort)
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

    private fun establishTunAndStartTun2Socks(socksPort: Int): Boolean {
        val (user, pass) = ParazitXRelayController.getSocksCredentials()
        if (user.isEmpty() || pass.isEmpty()) {
            Log.e(TAG, "establish: missing SOCKS credentials")
            return false
        }

        val fd: Int
        try {
            val builder = Builder()
                .setSession("ParazitX")
                .setMtu(VPN_MTU)
                .addAddress(VPN_ADDRESS, VPN_PREFIX)
                .addRoute("0.0.0.0", 0)
                .addDnsServer(VPN_DNS)
                .addDnsServer(VPN_DNS_FALLBACK)
                .setBlocking(false)

            // Self-exclusion: librelay's signaling WebSocket must escape
            // tun via the underlying network. Without this, a self-loop
            // forms through SOCKS5 and VK resets the peer within seconds.
            try {
                builder.addDisallowedApplication(packageName)
            } catch (e: Exception) {
                Log.e(TAG, "addDisallowedApplication failed", e)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                builder.setMetered(false)
            }

            val pfd = builder.establish()
                ?: throw IllegalStateException("VpnService.Builder.establish() returned null — permission?")
            tunFd = pfd
            fd = pfd.detachFd()
        } catch (e: Exception) {
            Log.e(TAG, "establish failed", e)
            return false
        }

        Log.i(TAG, "tun established fd=$fd, starting tun2socks → 127.0.0.1:$socksPort")

        tun2socksThread = Thread({
            try {
                Androidbind.startTun2Socks(
                    fd.toLong(),
                    VPN_MTU.toLong(),
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

    private fun stopSelfClean() {
        if (!isRunning && tunFd == null && !tun2socksStarted) {
            stopForegroundCompat()
            stopSelf()
            return
        }
        isRunning = false

        try {
            ParazitXRelayController.statusListener = null
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
        stopSelfClean()
        super.onDestroy()
    }

    private fun startForegroundNotification() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(NotificationManager::class.java)
            if (nm?.getNotificationChannel(CHANNEL_ID) == null) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "ParazitX tunnel",
                    NotificationManager.IMPORTANCE_LOW,
                ).apply { setShowBadge(false) }
                nm?.createNotificationChannel(channel)
            }
        }
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
    ): Boolean {
        if (VpnService.prepare(ctx) != null) {
            Log.w(TAG, "VPN not prepared — caller must show consent dialog")
            return false
        }
        val intent = Intent(ctx, ParazitXVpnService::class.java)
            .putExtra(ParazitXVpnService.EXTRA_JOIN_LINK, joinLink)
            .putExtra(ParazitXVpnService.EXTRA_SOCKS_PORT, socksPort)
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
