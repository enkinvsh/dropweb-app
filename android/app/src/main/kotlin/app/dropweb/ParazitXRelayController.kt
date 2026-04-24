package app.dropweb

import android.content.Context
import android.util.Log
import org.json.JSONObject
import java.io.BufferedWriter
import java.io.File
import java.io.OutputStreamWriter
import java.net.Inet4Address
import java.net.InetAddress
import java.security.SecureRandom

object ParazitXRelayController {
    private const val TAG = "ParazitXRelay"

    // Randomized per-process to avoid cross-app SOCKS hijack.
    private val socksUser: String = randomAlphaNum(16)
    private val socksPass: String = randomAlphaNum(24)

    private var process: Process? = null
    private var thread: Thread? = null
    private var stdinWriter: BufferedWriter? = null
    private val pendingCommands = mutableListOf<String>()

    @Volatile
    private var status: String = "disconnected"

    @Volatile
    var isRunning = false
        private set

    @Volatile
    var statusListener: ((String) -> Unit)? = null

    @Volatile
    var logListener: ((String) -> Unit)? = null

    @Synchronized
    fun start(ctx: Context, socksPort: Int, joinLink: String): String? {
        if (isRunning) {
            Log.i(TAG, "start: already running, resending AUTH")
            sendAuth(joinLink)
            return null
        }

        val binary = try {
            ensureBinary(ctx)
        } catch (e: Exception) {
            Log.e(TAG, "ensureBinary failed", e)
            return "ensureBinary: ${e.message}"
        }

        isRunning = true
        status = "starting"

        thread = Thread {
            try {
                val pb = ProcessBuilder(
                    binary.absolutePath,
                    "--mode", "vk-headless-joiner",
                    "--ws-port", "9001",
                    "--socks-port", socksPort.toString(),
                    "--socks-user", socksUser,
                    "--socks-pass", socksPass
                )
                pb.redirectErrorStream(true)
                val proc = pb.start()
                synchronized(this) {
                    process = proc
                    stdinWriter = BufferedWriter(OutputStreamWriter(proc.outputStream))
                    // Replay anything queued before the process was alive.
                    pendingCommands.forEach { writeStdin(it) }
                    pendingCommands.clear()
                }
                Log.i(
                    TAG,
                    "relay started: socks5://$socksUser:$socksPass@127.0.0.1:$socksPort"
                )

                // Send the initial join request.
                sendAuth(joinLink)

                proc.inputStream.bufferedReader().forEachLine { line ->
                    handleStdoutLine(line)
                }
                proc.waitFor()
                Log.i(TAG, "relay exited code=${proc.exitValue()}")
            } catch (e: Exception) {
                if (isRunning) {
                    Log.e(TAG, "relay thread error", e)
                }
            } finally {
                synchronized(this) {
                    isRunning = false
                    status = "TUNNEL_LOST"
                    process = null
                    stdinWriter = null
                }
                try { statusListener?.invoke("TUNNEL_LOST") } catch (_: Exception) {}
            }
        }.also { it.start() }

        return null
    }

    @Synchronized
    fun stop() {
        if (!isRunning && process == null) return
        isRunning = false
        process?.let {
            it.destroy()
            try { it.waitFor() } catch (_: InterruptedException) {}
        }
        process = null
        stdinWriter = null
        thread?.interrupt()
        thread = null
        pendingCommands.clear()
        status = "disconnected"
    }

    fun getStatus(): String = status

    fun getSocksCredentials(): Pair<String, String> = socksUser to socksPass

    private fun sendAuth(joinLink: String) {
        val json = JSONObject().apply {
            put("joinLink", joinLink)
            put("displayName", "AnonymUser")
            // "video" mode activates a VP8 keepalive track that stops VK from
            // kicking us for "idle peer" after ~14s. SOCKS traffic still
            // flows over the DC "tunnel" channel — video mode doesn't
            // disable it, it just adds a keepalive on top.
            put("tunnelMode", "video")
        }
        writeStdin("AUTH:$json")
    }

    private fun handleStdoutLine(line: String) {
        try { logListener?.invoke(line) } catch (e: Exception) {
            Log.e(TAG, "logListener threw", e)
        }
        when {
            line.startsWith("RESOLVE:") -> {
                val hostname = line.removePrefix("RESOLVE:")
                val ip = resolveHost(hostname)
                writeStdin(ip)
            }
            line.startsWith("STATUS:") -> {
                val s = line.removePrefix("STATUS:")
                status = s
                Log.i(TAG, "status=$s")
                try { statusListener?.invoke(s) } catch (e: Exception) {
                    Log.e(TAG, "statusListener threw", e)
                }
            }
            else -> Log.i(TAG, line)
        }
    }

    private fun resolveHost(hostname: String): String {
        return try {
            val all = InetAddress.getAllByName(hostname)
            val addr = all.firstOrNull { it is Inet4Address } ?: all.first()
            addr.hostAddress ?: ""
        } catch (e: Exception) {
            Log.e(TAG, "DNS resolve failed for $hostname", e)
            ""
        }
    }

    @Synchronized
    private fun writeStdin(line: String) {
        val w = stdinWriter
        if (w == null) {
            pendingCommands.add(line)
            return
        }
        try {
            w.write(line)
            w.newLine()
            w.flush()
        } catch (e: Exception) {
            Log.e(TAG, "writeStdin error: ${e.message}")
        }
    }

    // The relay Go binary is shipped as libparazitx-relay.so inside jniLibs/.
    // Android places it into nativeLibraryDir with the correct SELinux context
    // (apk_data_file:exec), which is the only directory where Android 10+
    // actually lets us exec() for our own package.
    private fun ensureBinary(ctx: Context): File {
        val libDir = ctx.applicationInfo.nativeLibraryDir
        val bin = File(libDir, "libparazitx-relay.so")
        if (!bin.exists()) {
            throw IllegalStateException(
                "libparazitx-relay.so missing in nativeLibraryDir=$libDir"
            )
        }
        return bin
    }

    private fun randomAlphaNum(length: Int): String {
        val chars = "abcdefghijklmnopqrstuvwxyz0123456789"
        val r = SecureRandom()
        return buildString {
            repeat(length) { append(chars[r.nextInt(chars.length)]) }
        }
    }
}
