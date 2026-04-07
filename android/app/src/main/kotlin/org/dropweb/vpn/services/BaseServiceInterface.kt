package org.dropweb.vpn.services

import android.annotation.SuppressLint
import android.app.Notification
import android.app.Notification.FOREGROUND_SERVICE_IMMEDIATE
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
import android.os.Build
import androidx.core.app.NotificationCompat
import org.dropweb.vpn.GlobalState
import org.dropweb.vpn.MainActivity
import org.dropweb.vpn.R
import org.dropweb.vpn.extensions.getActionPendingIntent
import org.dropweb.vpn.models.VpnOptions
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async

interface BaseServiceInterface {

    fun start(options: VpnOptions): Int

    fun stop()

    suspend fun startForeground(title: String, server: String?, content: String)
}

fun Service.createDropwebNotificationBuilder(): Deferred<NotificationCompat.Builder> =
    CoroutineScope(Dispatchers.Main).async {
        val stopText = GlobalState.getText("stop")
        val intent = Intent(this@createDropwebNotificationBuilder, MainActivity::class.java)

        val pendingIntent = if (Build.VERSION.SDK_INT >= 31) {
            PendingIntent.getActivity(
                this@createDropwebNotificationBuilder,
                0,
                intent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
        } else {
            PendingIntent.getActivity(
                this@createDropwebNotificationBuilder, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT
            )
        }

        with(
            NotificationCompat.Builder(
                this@createDropwebNotificationBuilder, GlobalState.NOTIFICATION_CHANNEL
            )
        ) {
            setSmallIcon(R.drawable.ic)
            setContentTitle("dropweb")
            setContentIntent(pendingIntent)
            setCategory(NotificationCompat.CATEGORY_SERVICE)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                foregroundServiceBehavior = FOREGROUND_SERVICE_IMMEDIATE
            }
            setOngoing(true)
            addAction(
                0, stopText, getActionPendingIntent("STOP")
            )
            setShowWhen(false)
            setOnlyAlertOnce(true)
        }
    }

@SuppressLint("ForegroundServiceType")
fun Service.startForeground(notification: Notification) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        val manager = getSystemService(NotificationManager::class.java)
        var channel = manager?.getNotificationChannel(GlobalState.NOTIFICATION_CHANNEL)
        if (channel == null) {
            channel = NotificationChannel(
                GlobalState.NOTIFICATION_CHANNEL, "SERVICE_CHANNEL", NotificationManager.IMPORTANCE_LOW
            )
            manager?.createNotificationChannel(channel)
        }
    }

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
        try {
            startForeground(
                GlobalState.NOTIFICATION_ID, notification, FOREGROUND_SERVICE_TYPE_DATA_SYNC
            )
        } catch (_: Exception) {
            startForeground(GlobalState.NOTIFICATION_ID, notification)
        }
    } else {
        startForeground(GlobalState.NOTIFICATION_ID, notification)
    }
}