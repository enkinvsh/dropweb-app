package app.dropweb

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.appcompat.app.AppCompatDelegate
import app.dropweb.plugins.AppPlugin
import app.dropweb.plugins.ServicePlugin
import app.dropweb.plugins.TilePlugin
import app.dropweb.plugins.VpnPlugin
import app.dropweb.services.ParazitXVpnController
import app.dropweb.services.ParazitXVpnService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        applyAppTheme()

        // Post-reboot Android restores our Task from persistent state and passes
        // a savedInstanceState pointing at the killed process's FlutterEngine.
        // FlutterActivity.onCreate then blocks trying to restore engine state
        // that doesn't exist — splash hangs forever. We don't use Flutter's
        // restoration API, so always start fresh.
        super.onCreate(null)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.attributes.preferredDisplayModeId = getHighestRefreshRateDisplayMode()
        }
    }

    private fun getHighestRefreshRateDisplayMode(): Int {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val modes = windowManager.defaultDisplay.supportedModes
            var maxRefreshRate = 60f
            var modeId = 0
            
            for (mode in modes) {
                if (mode.refreshRate > maxRefreshRate) {
                    maxRefreshRate = mode.refreshRate
                    modeId = mode.modeId
                }
            }
            return modeId
        }
        return 0
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Platform Channel for getting Android ID
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.dropweb/device_id")
            .setMethodCallHandler { call, result ->
                if (call.method == "getAndroidId") {
                    try {
                        val androidId = Settings.Secure.getString(
                            contentResolver,
                            Settings.Secure.ANDROID_ID
                        )
                        result.success(androidId)
                    } catch (e: Exception) {
                        result.error("ANDROID_ID_ERROR", "Failed to get Android ID: ${e.message}", null)
                    }
                } else {
                    result.notImplemented()
                }
            }
        
        // Cross-process status bridge: ParazitXVpnService lives in `:parazitx`
        // (dedicated process so FGS policy can't freeze librelay). It
        // sends status via package-scoped broadcast; we forward to Flutter.
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "app.dropweb/vktunnel/status",
        ).setStreamHandler(object : EventChannel.StreamHandler {
            private var receiver: BroadcastReceiver? = null
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                val uiHandler = android.os.Handler(android.os.Looper.getMainLooper())
                val r = object : BroadcastReceiver() {
                    override fun onReceive(ctx: Context, intent: Intent) {
                        val status = intent.getStringExtra(ParazitXVpnService.EXTRA_STATUS)
                            ?: return
                        uiHandler.post { events.success(status) }
                    }
                }
                val filter = IntentFilter(ParazitXVpnService.BROADCAST_STATUS)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    registerReceiver(r, filter, Context.RECEIVER_NOT_EXPORTED)
                } else {
                    @Suppress("UnspecifiedRegisterReceiverFlag")
                    registerReceiver(r, filter)
                }
                receiver = r
                // If the service is already running (app reopened while VPN
                // active), ask it to rebroadcast its current status so the
                // UI can bootstrap without waiting for the next transition.
                ParazitXVpnController.queryStatus(applicationContext)
            }
            override fun onCancel(arguments: Any?) {
                try { receiver?.let { unregisterReceiver(it) } } catch (_: Exception) {}
                receiver = null
            }
        })

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "app.dropweb/parazitx/logs",
        ).setStreamHandler(object : EventChannel.StreamHandler {
            private var receiver: BroadcastReceiver? = null
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                val uiHandler = android.os.Handler(android.os.Looper.getMainLooper())
                val r = object : BroadcastReceiver() {
                    override fun onReceive(ctx: Context, intent: Intent) {
                        val line = intent.getStringExtra(ParazitXVpnService.EXTRA_LOG_LINE)
                            ?: return
                        uiHandler.post { events.success(line) }
                    }
                }
                val filter = IntentFilter(ParazitXVpnService.BROADCAST_LOG)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    registerReceiver(r, filter, Context.RECEIVER_NOT_EXPORTED)
                } else {
                    @Suppress("UnspecifiedRegisterReceiverFlag")
                    registerReceiver(r, filter)
                }
                receiver = r
            }
            override fun onCancel(arguments: Any?) {
                try { receiver?.let { unregisterReceiver(it) } } catch (_: Exception) {}
                receiver = null
            }
        })

        val appPlugin = AppPlugin()
        flutterEngine.plugins.add(appPlugin)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.dropweb/parazitx_vpn")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val args = call.arguments as? Map<String, Any?> ?: emptyMap()
                        val joinLink = args["joinLink"] as? String ?: ""
                        val port = (args["socksPort"] as? Number)?.toInt() ?: 1080
                        if (joinLink.isEmpty()) {
                            result.error(
                                "BAD_ARGS",
                                "joinLink required",
                                null,
                            )
                            return@setMethodCallHandler
                        }
                        // Reuse AppPlugin's VPN consent flow — it registers its
                        // activity-result listener through ActivityPluginBinding,
                        // so the FlutterActivity keeps its EGL context across
                        // the consent dialog round trip. Doing prepare+launch
                        // directly from MainActivity.onActivityResult breaks
                        // Impeller's EGL state on Pixel 10 (black screen).
                        appPlugin.requestVpnPermission {
                            val started = ParazitXVpnController.start(
                                applicationContext, port, joinLink,
                            )
                            if (started) result.success(null)
                            else result.error(
                                "VPN_PREPARE_FAILED",
                                "prepare returned non-null after consent",
                                null,
                            )
                        }
                    }
                    "stop" -> {
                        ParazitXVpnController.stop(applicationContext)
                        result.success(null)
                    }
                    "isRunning" -> {
                        result.success(ParazitXVpnController.isRunning)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "app.dropweb/parazitx_notifications",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "showActionRequired" -> {
                    val nm = getSystemService(NotificationManager::class.java)
                    
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        if (nm?.getNotificationChannel("parazitx_action") == null) {
                            val channel = NotificationChannel(
                                "parazitx_action",
                                "Требуется действие",
                                NotificationManager.IMPORTANCE_HIGH
                            ).apply {
                                description = "Уведомления когда нужно подтвердить соединение"
                                enableVibration(true)
                                enableLights(true)
                                setShowBadge(true)
                            }
                            nm?.createNotificationChannel(channel)
                        }
                    }
                    
                    val openIntent = PendingIntent.getActivity(
                        this,
                        2,
                        Intent(this, MainActivity::class.java).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                                Intent.FLAG_ACTIVITY_SINGLE_TOP
                        },
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                    )
                    
                    val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        Notification.Builder(this, "parazitx_action")
                    } else {
                        @Suppress("DEPRECATION")
                        Notification.Builder(this).setPriority(Notification.PRIORITY_HIGH)
                    }
                    
                    builder.apply {
                        setContentTitle("ParazitX: требуется действие")
                        setContentText("Нажмите чтобы продолжить соединение")
                        setSmallIcon(R.mipmap.ic_launcher_foreground)
                        setContentIntent(openIntent)
                        setAutoCancel(true)
                        setCategory(Notification.CATEGORY_CALL)
                        setFullScreenIntent(openIntent, true)
                    }
                    
                    nm?.notify(0x178A, builder.build())
                    result.success(null)
                }
                "dismissActionRequired" -> {
                    val nm = getSystemService(NotificationManager::class.java)
                    nm?.cancel(0x178A)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        flutterEngine.plugins.add(ServicePlugin)
        flutterEngine.plugins.add(TilePlugin())
        flutterEngine.plugins.add(VpnPlugin)
        GlobalState.flutterEngine = flutterEngine

        // Sync VPN status when app opens - this ensures UI reflects actual VPN state
        // especially important when VPN was started via Tile while app was not in memory
        GlobalState.syncStatus()
    }

    override fun onDestroy() {
        GlobalState.flutterEngine = null
        // Don't reset runState here - VPN might still be running via serviceEngine
        // The runState is managed by VpnPlugin.handleStart/handleStop
        super.onDestroy()
    }

    private fun applyAppTheme() {
        try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val configJson = prefs.getString("flutter.config", null)
            
            if (configJson != null) {
                val config = JSONObject(configJson)
                val themeProps = config.optJSONObject("themeProps")
                val themeMode = themeProps?.optString("themeMode", "ThemeMode.system") ?: "ThemeMode.system"
                
                when {
                    themeMode.contains("light", ignoreCase = true) -> {
                        AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_NO)
                    }
                    themeMode.contains("dark", ignoreCase = true) -> {
                        AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_YES)
                    }
                    else -> {
                        AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM)
                    }
                }
            } else {
                // Default to system theme if config not found
                AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM)
            }
        } catch (e: Exception) {
            // Fallback to system theme on error
            AppCompatDelegate.setDefaultNightMode(AppCompatDelegate.MODE_NIGHT_FOLLOW_SYSTEM)
        }
    }
}