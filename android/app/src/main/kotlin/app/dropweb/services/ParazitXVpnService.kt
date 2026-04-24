package app.dropweb.services

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import androidbind.Androidbind
import app.dropweb.MainActivity
import app.dropweb.R

/**
 * Standalone VpnService for ParazitX mode.
 *
 * Flow:
 *   1. [start] builds a tun with 0.0.0.0/0 route, excludes our own package
 *      so [app.dropweb.ParazitXRelayController]'s librelay process reaches
 *      VK SFU through the underlying network (not through tun -> self loop).
 *   2. [Androidbind.startTun2Socks] forwards all tun packets to
 *      127.0.0.1:{socksPort}, where librelay exposes a SOCKS5 listener that
 *      bridges into the VK WebRTC data channel.
 *
 * Mutually exclusive with [DropwebVpnService] — Android allows only one
 * active VpnService at a time. [app.dropweb.ParazitXManager] is responsible
 * for stopping mihomo first.
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

        const val EXTRA_SOCKS_PORT = "socks_port"
        const val EXTRA_SOCKS_USER = "socks_user"
        const val EXTRA_SOCKS_PASS = "socks_pass"
        const val ACTION_STOP = "app.dropweb.parazitx.STOP"

        @Volatile
        var isRunning: Boolean = false
            private set
    }

    private var tunFd: ParcelFileDescriptor? = null
    private var tun2socksThread: Thread? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelfClean()
            return START_NOT_STICKY
        }
        val port = intent?.getIntExtra(EXTRA_SOCKS_PORT, 1080) ?: 1080
        val user = intent?.getStringExtra(EXTRA_SOCKS_USER).orEmpty()
        val pass = intent?.getStringExtra(EXTRA_SOCKS_PASS).orEmpty()
        if (user.isEmpty() || pass.isEmpty()) {
            Log.e(TAG, "start: missing SOCKS credentials")
            stopSelf()
            return START_NOT_STICKY
        }
        return if (start(port, user, pass)) START_STICKY else START_NOT_STICKY
    }

    private fun start(socksPort: Int, socksUser: String, socksPass: String): Boolean {
        if (isRunning) {
            Log.i(TAG, "start: already running")
            return true
        }

        startForegroundNotification()

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

            // CRITICAL self-exclusion: librelay's signaling WebSocket must
            // escape tun via the underlying network. If tun swallows it, a
            // self-loop forms through SOCKS5 and the VK SFU resets the
            // connection within seconds.
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
            stopSelfClean()
            return false
        }

        Log.i(TAG, "tun established fd=$fd, starting tun2socks → 127.0.0.1:$socksPort")

        tun2socksThread = Thread({
            try {
                Androidbind.startTun2Socks(
                    fd.toLong(),
                    VPN_MTU.toLong(),
                    socksPort.toLong(),
                    socksUser,
                    socksPass,
                )
                Log.i(TAG, "tun2socks returned (goroutines keep running in background)")
            } catch (e: Exception) {
                Log.e(TAG, "tun2socks threw", e)
                stopSelfClean()
            }
        }, "parazitx-tun2socks").also { it.start() }

        isRunning = true
        return true
    }

    private fun stopSelfClean() {
        if (!isRunning && tunFd == null) {
            stopForegroundCompat()
            stopSelf()
            return
        }
        isRunning = false
        try {
            Androidbind.stopTun2Socks()
        } catch (e: Exception) {
            Log.e(TAG, "stopTun2Socks threw", e)
        }
        tun2socksThread?.interrupt()
        tun2socksThread = null
        try {
            tunFd?.close()
        } catch (e: Exception) {
            Log.e(TAG, "tunFd close threw", e)
        }
        tunFd = null
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

/** Helpers for the rest of the app to talk to [ParazitXVpnService] cleanly. */
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
        socksUser: String,
        socksPass: String,
    ): Boolean {
        if (VpnService.prepare(ctx) != null) {
            Log.w(TAG, "VPN not prepared — caller must show consent dialog")
            return false
        }
        val intent = Intent(ctx, ParazitXVpnService::class.java)
            .putExtra(ParazitXVpnService.EXTRA_SOCKS_PORT, socksPort)
            .putExtra(ParazitXVpnService.EXTRA_SOCKS_USER, socksUser)
            .putExtra(ParazitXVpnService.EXTRA_SOCKS_PASS, socksPass)
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

    val isRunning: Boolean get() = ParazitXVpnService.isRunning
}
