package app.dropweb

import android.content.Context

object VkTunnelManager {
    fun startTunnel(ctx: Context, joinLink: String, socksPort: Int): String? {
        return ParazitXRelayController.start(ctx, socksPort, joinLink)
    }

    fun stopTunnel() {
        ParazitXRelayController.stop()
    }

    fun getStatus(): String = ParazitXRelayController.getStatus()

    fun getSocksCredentials(): Pair<String, String> =
        ParazitXRelayController.getSocksCredentials()
}
