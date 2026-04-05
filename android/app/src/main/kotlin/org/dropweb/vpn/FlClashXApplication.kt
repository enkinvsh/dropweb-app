package org.dropweb.vpn;

import android.app.Application
import android.content.Context

class FlClashXApplication : Application() {
    companion object {
        private lateinit var instance: FlClashXApplication
        fun getAppContext(): Context {
            return instance.applicationContext
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
    }
}