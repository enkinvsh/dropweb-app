package app.dropweb.services

import android.annotation.SuppressLint
import android.content.Intent
import android.net.ProxyInfo
import android.net.VpnService
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.os.Parcel
import android.os.RemoteException
import android.util.Log
import androidx.core.app.NotificationCompat
import app.dropweb.GlobalState
import app.dropweb.extensions.getIpv4RouteAddress
import app.dropweb.extensions.getIpv6RouteAddress
import app.dropweb.extensions.toCIDR
import app.dropweb.models.AccessControlMode
import app.dropweb.models.VpnOptions
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch


class DropwebVpnService : VpnService(), BaseServiceInterface {
    override fun onCreate() {
        super.onCreate()
        GlobalState.initServiceEngine()
    }

    override fun start(options: VpnOptions): Int {
        return with(Builder()) {
            if (options.ipv4Address.isNotEmpty()) {
                val cidr = options.ipv4Address.toCIDR()
                addAddress(cidr.address, cidr.prefixLength)
                Log.d(
                    "addAddress",
                    "address: ${cidr.address} prefixLength:${cidr.prefixLength}"
                )
                val routeAddress = options.getIpv4RouteAddress()
                if (routeAddress.isNotEmpty()) {
                    try {
                        routeAddress.forEach { i ->
                            Log.d(
                                "addRoute4",
                                "address: ${i.address} prefixLength:${i.prefixLength}"
                            )
                            addRoute(i.address, i.prefixLength)
                        }
                    } catch (_: Exception) {
                        addRoute("0.0.0.0", 0)
                    }
                } else {
                    addRoute("0.0.0.0", 0)
                }
            } else {
                addRoute("0.0.0.0", 0)
            }
            try {
                if (options.ipv6Address.isNotEmpty()) {
                    val cidr = options.ipv6Address.toCIDR()
                    Log.d(
                        "addAddress6",
                        "address: ${cidr.address} prefixLength:${cidr.prefixLength}"
                    )
                    addAddress(cidr.address, cidr.prefixLength)
                    val routeAddress = options.getIpv6RouteAddress()
                    if (routeAddress.isNotEmpty()) {
                        try {
                            routeAddress.forEach { i ->
                                Log.d(
                                    "addRoute6",
                                    "address: ${i.address} prefixLength:${i.prefixLength}"
                                )
                                addRoute(i.address, i.prefixLength)
                            }
                        } catch (_: Exception) {
                            addRoute("::", 0)
                        }
                    } else {
                        addRoute("::", 0)
                    }
                }
            }catch (_:Exception){
                Log.d(
                    "addAddress6",
                    "IPv6 is not supported."
                )
            }
            addDnsServer(options.dnsServerAddress)
            setMtu(9000)
            val include = options.includePackage.orEmpty()
            val exclude = options.excludePackage.orEmpty()
            when {
                include.isNotEmpty() -> {
                    (include + packageName).distinct().forEach { pkg ->
                        try {
                            addAllowedApplication(pkg)
                        } catch (_: Exception) {
                            Log.d("VpnService", "addAllowedApplication failed: $pkg")
                        }
                    }
                }
                exclude.isNotEmpty() -> {
                    (exclude - packageName).forEach { pkg ->
                        try {
                            addDisallowedApplication(pkg)
                        } catch (_: Exception) {
                            Log.d("VpnService", "addDisallowedApplication failed: $pkg")
                        }
                    }
                }
                else -> options.accessControl.let { accessControl ->
                    if (accessControl.enable) {
                        when (accessControl.mode) {
                            AccessControlMode.acceptSelected -> {
                                (accessControl.acceptList + packageName).forEach {
                                    try {
                                        addAllowedApplication(it)
                                    } catch (_: Exception) {
                                        Log.d("VpnService", "addAllowedApplication failed: $it")
                                    }
                                }
                            }
                            AccessControlMode.rejectSelected -> {
                                (accessControl.rejectList - packageName).forEach {
                                    try {
                                        addDisallowedApplication(it)
                                    } catch (_: Exception) {
                                        Log.d("VpnService", "addDisallowedApplication failed: $it")
                                    }
                                }
                            }
                        }
                    }
                }
            }
            setSession("dropweb")
            setBlocking(false)
            if (Build.VERSION.SDK_INT >= 29) {
                setMetered(false)
            }
            if (options.allowBypass) {
                allowBypass()
            }
            establish()?.detachFd()
                ?: throw NullPointerException("Establish VPN rejected by system")
        }
    }

    override fun stop() {
        stopSelf()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        }
    }

    private var cachedBuilder: NotificationCompat.Builder? = null

    private suspend fun notificationBuilder(): NotificationCompat.Builder {
        if (cachedBuilder == null) {
            cachedBuilder = createDropwebNotificationBuilder().await()
        }
        return cachedBuilder!!
    }

    @SuppressLint("ForegroundServiceType")
    override suspend fun startForeground(title: String, server: String?, content: String) {
        startForeground(
            notificationBuilder()
                .setContentTitle(title)
                .setContentText(content)
                .setSubText(server ?: "")
                .build()
        )
    }

    override fun onTrimMemory(level: Int) {
        super.onTrimMemory(level)
        GlobalState.getCurrentVPNPlugin()?.requestGc()
    }

    private val binder = LocalBinder()

    inner class LocalBinder : Binder() {
        fun getService(): DropwebVpnService = this@DropwebVpnService

        override fun onTransact(code: Int, data: Parcel, reply: Parcel?, flags: Int): Boolean {
            try {
                val isSuccess = super.onTransact(code, data, reply, flags)
                if (!isSuccess) {
                    CoroutineScope(Dispatchers.Main).launch {
                        GlobalState.getCurrentTilePlugin()?.handleStop()
                    }
                }
                return isSuccess
            } catch (e: RemoteException) {
                throw e
            }
        }
    }

    override fun onBind(intent: Intent): IBinder {
        return binder
    }

    override fun onUnbind(intent: Intent?): Boolean {
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        stop()
        super.onDestroy()
    }
}