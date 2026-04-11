package app.dropweb.widgets

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import app.dropweb.GlobalState
import app.dropweb.R
import app.dropweb.RunState
import app.dropweb.extensions.getActionPendingIntent

class DropwebWidgetProvider : AppWidgetProvider() {

    companion object {
        fun updateAllWidgets(context: Context) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(
                ComponentName(context, DropwebWidgetProvider::class.java)
            )
            if (ids.isNotEmpty()) {
                val intent = Intent(context, DropwebWidgetProvider::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                }
                context.sendBroadcast(intent)
            }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            updateWidget(context, appWidgetManager, id)
        }
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val isConnected = GlobalState.runState.value == RunState.START

        val views = RemoteViews(context.packageName, R.layout.widget_vpn)

        val bgRes = if (isConnected) R.drawable.widget_btn_on else R.drawable.widget_btn_ripple
        views.setInt(R.id.widget_icon, "setBackgroundResource", bgRes)

        val iconTint = if (isConnected) 0xFF22C55E.toInt() else 0x80FFFFFF.toInt()
        views.setInt(R.id.widget_icon, "setColorFilter", iconTint)

        views.setOnClickPendingIntent(R.id.widget_icon, context.getActionPendingIntent("CHANGE"))

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
}
