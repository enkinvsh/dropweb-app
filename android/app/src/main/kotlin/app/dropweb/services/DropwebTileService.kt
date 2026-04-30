package app.dropweb.services

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.util.Log
import androidx.annotation.RequiresApi
import androidx.lifecycle.Observer
import app.dropweb.GlobalState
import app.dropweb.RunState


@RequiresApi(Build.VERSION_CODES.N)
class DropwebTileService : TileService() {

    companion object {
        private const val TAG = "DropwebTileService"

        // Cached so the tile renders correctly the moment Quick Settings
        // opens, before the QUERY_STATUS rebroadcast round-trip completes.
        @Volatile
        private var lastParazitxStatus: String = "disconnected"
    }

    private val mihomoObserver = Observer<RunState> { _ ->
        refreshTile()
    }

    // ParazitXVpnService runs in `:parazitx` (separate process so FGS policy
    // can't freeze librelay). Status comes in as a package-scoped broadcast.
    private val parazitxReceiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context, intent: Intent) {
            val status = intent.getStringExtra(ParazitXVpnService.EXTRA_STATUS)
                ?: return
            Log.d(TAG, "parazitx status: $status")
            lastParazitxStatus = status
            refreshTile()
        }
    }
    private var parazitxReceiverRegistered: Boolean = false

    private fun parazitxActive(status: String): Boolean = when (status) {
        "TUNNEL_CONNECTED", "TUNNEL_ACTIVE" -> true
        else -> false
    }

    private fun parazitxConnecting(status: String): Boolean {
        if (status.isEmpty()) return false
        if (status == "disconnected") return false
        if (status == "TUNNEL_LOST") return false
        if (status.startsWith("ERROR:")) return false
        if (parazitxActive(status)) return false
        return true
    }

    private fun refreshTile() {
        val tile = qsTile ?: return

        val parazitxStatus = lastParazitxStatus
        val parazitxOn = parazitxActive(parazitxStatus)
        val parazitxBusy = parazitxConnecting(parazitxStatus)
        val mihomoState = GlobalState.runState.value
        val hasProfile = GlobalState.hasActiveProfile()

        // Android only allows one VpnService at a time, so when ParazitX
        // owns the VPN slot, mihomo state is irrelevant for tile display.
        tile.state = when {
            parazitxOn -> Tile.STATE_ACTIVE
            parazitxBusy -> Tile.STATE_UNAVAILABLE
            !hasProfile -> Tile.STATE_UNAVAILABLE
            else -> when (mihomoState) {
                RunState.START -> Tile.STATE_ACTIVE
                RunState.PENDING -> Tile.STATE_UNAVAILABLE
                RunState.STOP, null -> Tile.STATE_INACTIVE
            }
        }
        tile.updateTile()
    }

    override fun onStartListening() {
        super.onStartListening()

        // Register receiver BEFORE asking for status, otherwise the
        // rebroadcast can race ahead of our registration.
        if (!parazitxReceiverRegistered) {
            val filter = IntentFilter(ParazitXVpnService.BROADCAST_STATUS)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(parazitxReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                @Suppress("UnspecifiedRegisterReceiverFlag")
                registerReceiver(parazitxReceiver, filter)
            }
            parazitxReceiverRegistered = true
        }

        GlobalState.syncStatus()
        GlobalState.runState.observeForever(mihomoObserver)
        ParazitXVpnController.queryStatus(applicationContext)

        refreshTile()
    }

    override fun onStopListening() {
        GlobalState.runState.removeObserver(mihomoObserver)
        if (parazitxReceiverRegistered) {
            try {
                unregisterReceiver(parazitxReceiver)
            } catch (_: Exception) {
            }
            parazitxReceiverRegistered = false
        }
        super.onStopListening()
    }

    override fun onClick() {
        unlockAndRun {
            val parazitxStatus = lastParazitxStatus
            val parazitxOn = parazitxActive(parazitxStatus)
            val parazitxBusy = parazitxConnecting(parazitxStatus)

            when {
                parazitxOn -> {
                    // Tile can stop ParazitX but not start it: starting
                    // requires the VK login flow + VPN consent activity
                    // result, which can only run from MainActivity.
                    ParazitXVpnController.stop(applicationContext)
                }
                parazitxBusy -> {
                    // Mid-handshake: ignore taps to avoid tearing down
                    // the tunnel while it's still establishing.
                }
                else -> when (qsTile?.state) {
                    Tile.STATE_INACTIVE -> GlobalState.handleStart()
                    Tile.STATE_ACTIVE -> GlobalState.handleStop()
                    Tile.STATE_UNAVAILABLE -> Unit
                    else -> GlobalState.handleToggle()
                }
            }
        }
    }

    override fun onDestroy() {
        GlobalState.runState.removeObserver(mihomoObserver)
        if (parazitxReceiverRegistered) {
            try {
                unregisterReceiver(parazitxReceiver)
            } catch (_: Exception) {
            }
            parazitxReceiverRegistered = false
        }
        super.onDestroy()
    }
}
