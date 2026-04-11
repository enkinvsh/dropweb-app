package app.dropweb

import android.app.Activity
import android.os.Bundle
import app.dropweb.extensions.wrapAction

class TempActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        when (intent.action) {
            wrapAction("START") -> {
                GlobalState.handleStart()
            }

            wrapAction("STOP") -> {
                GlobalState.handleStop()
            }

            wrapAction("CHANGE") -> {
                GlobalState.handleToggle()
            }
        }
        finishAndRemoveTask()
    }
}