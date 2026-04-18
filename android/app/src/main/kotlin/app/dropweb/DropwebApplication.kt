package app.dropweb;

import android.app.Application
import android.content.Context
import androidx.lifecycle.Observer
import app.dropweb.widgets.DropwebWidgetProvider
import io.flutter.FlutterInjector

class DropwebApplication : Application() {
    companion object {
        private lateinit var instance: DropwebApplication
        fun getAppContext(): Context {
            return instance.applicationContext
        }
    }

    private val widgetObserver = Observer<RunState> {
        DropwebWidgetProvider.updateAllWidgets(this)
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
        GlobalState.runState.observeForever(widgetObserver)

        // Pre-warm the Flutter native library loader on the Application
        // thread. Without this, the first-ever call (which happens deep
        // inside MainActivity's super.onCreate on the Android UI thread)
        // has to load libflutter.so, snapshot, and set up the native
        // callback table while holding the UI-thread message queue.
        // On post-reboot, combined with VpnService START_STICKY revival
        // that creates a service FlutterEngine in parallel, the two
        // loader paths race and the main engine never finishes its Dart
        // entrypoint handshake — splash stays up forever.
        FlutterInjector.instance().flutterLoader().startInitialization(applicationContext)
    }
}