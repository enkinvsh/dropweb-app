package app.dropweb;

import android.app.Application
import android.content.Context

class DropwebApplication : Application() {
    companion object {
        private lateinit var instance: DropwebApplication
        fun getAppContext(): Context {
            return instance.applicationContext
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
    }
}