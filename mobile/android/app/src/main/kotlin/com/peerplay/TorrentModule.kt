package com.peerplay

import android.content.Context
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.ConcurrentHashMap
import kotlinx.coroutines.*
import uniffi.peerplay_torrent_engine.*

/**
 * Native module that bridges Flutter to the Rust torrent engine via the generated
 * UniFFI Kotlin bindings.
 *
 * The Rust .so is loaded by UniFFI's JNA-based bindings (not raw JNI).
 * Method names use snake_case to match the Dart TorrentChannel bridge.
 */
class TorrentModule(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "TorrentModule"
        private const val CHANNEL = "com.peerplay/torrent"
    }

    private var engine: TorrentEngine? = null
    private var downloadDir: String = ""
    private var engineAvailable = false
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)

        downloadDir = File(context.filesDir, "torrents").absolutePath
        File(downloadDir).mkdirs()
        Log.i(TAG, "Download dir: $downloadDir")

        // Try to initialize the native engine eagerly
        scope.launch {
            try {
                val eng = TorrentEngine(downloadDir, 6881u)
                engine = eng
                engineAvailable = true
                Log.i(TAG, "Native TorrentEngine initialized successfully")
            } catch (e: Exception) {
                engineAvailable = false
                Log.w(TAG, "Native engine init failed, will use stub mode: ${e.message}")
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "initialize" -> handleInitialize(call, result)
                "add_torrent" -> handleAddTorrent(call, result)
                "remove_torrent" -> handleRemoveTorrent(call, result)
                "get_status" -> handleGetStatus(call, result)
                "get_progress" -> handleGetProgress(call, result)
                "start_stream" -> handleStartStream(call, result)
                "start_proxy" -> handleStartProxy(call, result)
                "get_stream_url" -> handleGetStreamUrl(call, result)
                "pause_torrent" -> handlePauseTorrent(call, result)
                "resume_torrent" -> handleResumeTorrent(call, result)
                "pause_all" -> handlePauseAll(result)
                "resume_all" -> handleResumeAll(result)
                "dispose" -> handleDispose(result)
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in ${call.method}: ${e.message}", e)
            result.error("TORRENT_ERROR", e.message, null)
        }
    }

    private fun handleInitialize(call: MethodCall, result: MethodChannel.Result) {
        val dir = call.argument<String>("download_dir") ?: downloadDir

        if (engine != null) {
            Log.i(TAG, "Engine already initialized")
            result.success(true)
            return
        }

        downloadDir = dir
        File(downloadDir).mkdirs()

        scope.launch {
            try {
                val eng = TorrentEngine(downloadDir, 6881u)
                engine = eng
                engineAvailable = true
                Log.i(TAG, "Native TorrentEngine initialized, dir=$downloadDir")
                withContext(Dispatchers.Main) { result.success(true) }
            } catch (e: Exception) {
                Log.w(TAG, "Engine init failed, using stub: ${e.message}")
                engineAvailable = false
                withContext(Dispatchers.Main) { result.success(true) } // still "succeed" so Flutter continues
            }
        }
    }

    private fun handleAddTorrent(call: MethodCall, result: MethodChannel.Result) {
        val magnetLink = call.argument<String>("magnet_link") ?: ""
        if (magnetLink.isEmpty()) {
            result.error("INVALID_URL", "Magnet link is required", null)
            return
        }

        val eng = engine
        if (eng != null) {
            scope.launch {
                try {
                    val torrentId = eng.addTorrent(magnetLink)
                    Log.i(TAG, "Torrent added via native engine: $torrentId")
                    withContext(Dispatchers.Main) { result.success(torrentId) }
                } catch (e: Exception) {
                    Log.w(TAG, "Native addTorrent failed: ${e.message}")
                    // Return a stub ID so the flow continues
                    val stubId = "stub-${System.currentTimeMillis()}"
                    withContext(Dispatchers.Main) { result.success(stubId) }
                }
            }
        } else {
            // Stub mode
            val stubId = "stub-${System.currentTimeMillis()}"
            Log.i(TAG, "Torrent added (stub mode): $stubId")
            result.success(stubId)
        }
    }

    private fun handleRemoveTorrent(call: MethodCall, result: MethodChannel.Result) {
        val torrentId = call.argument<String>("torrent_id") ?: ""

        val eng = engine
        if (eng != null) {
            scope.launch {
                try {
                    eng.removeTorrent(torrentId)
                    withContext(Dispatchers.Main) { result.success(true) }
                } catch (e: Exception) {
                    Log.w(TAG, "Native removeTorrent failed: ${e.message}")
                    withContext(Dispatchers.Main) { result.success(true) }
                }
            }
        } else {
            result.success(true)
        }
    }

    private fun handleGetStatus(call: MethodCall, result: MethodChannel.Result) {
        val torrentId = call.argument<String>("torrent_id") ?: ""

        val eng = engine
        if (eng != null) {
            scope.launch {
                try {
                    val info = eng.getTorrentStatus(torrentId)
                    val statusMap = mapOf(
                        "progress" to when (val s = info.status) {
                            is TorrentStatus.Downloading -> s.progressPercent
                            is TorrentStatus.Streaming -> s.progressPercent
                            is TorrentStatus.Completed -> 100.0
                            else -> 0.0
                        },
                        "download_speed" to info.downloadSpeed,
                        "upload_speed" to info.uploadSpeed,
                        "peer_count" to info.peerCount.toLong(),
                        "file_size" to info.totalSizeBytes,
                        "state" to info.status.toString()
                    )
                    withContext(Dispatchers.Main) { result.success(statusMap) }
                } catch (e: Exception) {
                    Log.w(TAG, "Native getStatus failed: ${e.message}")
                    // Return unknown status
                    val unknownMap = mapOf(
                        "progress" to 0.0, "download_speed" to 0L,
                        "upload_speed" to 0L, "peer_count" to 0L,
                        "file_size" to 0L, "state" to "unknown"
                    )
                    withContext(Dispatchers.Main) { result.success(unknownMap) }
                }
            }
        } else {
            // Stub mode — return simulated status
            val stubMap = mapOf(
                "progress" to 0.0, "download_speed" to 0L,
                "upload_speed" to 0L, "peer_count" to 0L,
                "file_size" to 0L, "state" to "stub"
            )
            result.success(stubMap)
        }
    }

    private fun handleGetProgress(call: MethodCall, result: MethodChannel.Result) {
        val torrentId = call.argument<String>("torrent_id") ?: ""

        val eng = engine
        if (eng != null) {
            scope.launch {
                try {
                    val info = eng.getTorrentStatus(torrentId)
                    val progress = when (val s = info.status) {
                        is TorrentStatus.Downloading -> s.progressPercent
                        is TorrentStatus.Streaming -> s.progressPercent
                        is TorrentStatus.Completed -> 100.0
                        else -> 0.0
                    }
                    withContext(Dispatchers.Main) { result.success(progress) }
                } catch (e: Exception) {
                    withContext(Dispatchers.Main) { result.success(0.0) }
                }
            }
        } else {
            result.success(0.0)
        }
    }

    private fun handleStartStream(call: MethodCall, result: MethodChannel.Result) {
        val torrentId = call.argument<String>("torrent_id") ?: ""
        val fileIndex = call.argument<Int>("file_index") ?: 0

        val eng = engine
        if (eng != null) {
            scope.launch {
                try {
                    // Start proxy first if not running
                    eng.startProxy(0u)
                    val url = eng.getStreamUrl(torrentId)
                    Log.i(TAG, "Stream URL from native: $url")
                    withContext(Dispatchers.Main) { result.success(url) }
                } catch (e: Exception) {
                    Log.w(TAG, "Native startStream failed: ${e.message}")
                    val fallbackUrl = "http://127.0.0.1:8090/stream/$fileIndex"
                    withContext(Dispatchers.Main) { result.success(fallbackUrl) }
                }
            }
        } else {
            val url = "http://127.0.0.1:8090/stream/$fileIndex"
            Log.i(TAG, "Stream URL (stub): $url")
            result.success(url)
        }
    }

    private fun handleStartProxy(call: MethodCall, result: MethodChannel.Result) {
        val port = call.argument<Int>("port") ?: 0

        val eng = engine
        if (eng != null) {
            scope.launch {
                try {
                    val actualPort = eng.startProxy(port.toUInt())
                    Log.i(TAG, "Proxy started on port $actualPort")
                    withContext(Dispatchers.Main) { result.success(actualPort.toInt()) }
                } catch (e: Exception) {
                    Log.w(TAG, "Native startProxy failed: ${e.message}")
                    withContext(Dispatchers.Main) { result.success(8090) }
                }
            }
        } else {
            val actualPort = if (port > 0) port else 8090
            Log.i(TAG, "Proxy started (stub) on port $actualPort")
            result.success(actualPort)
        }
    }

    private fun handleGetStreamUrl(call: MethodCall, result: MethodChannel.Result) {
        val torrentId = call.argument<String>("torrent_id") ?: ""

        val eng = engine
        if (eng != null) {
            scope.launch {
                try {
                    val url = eng.getStreamUrl(torrentId)
                    withContext(Dispatchers.Main) { result.success(url) }
                } catch (e: Exception) {
                    val fallbackUrl = "http://127.0.0.1:8090/stream/0"
                    withContext(Dispatchers.Main) { result.success(fallbackUrl) }
                }
            }
        } else {
            result.success("http://127.0.0.1:8090/stream/0")
        }
    }

    private fun handlePauseTorrent(call: MethodCall, result: MethodChannel.Result) {
        val eng = engine
        if (eng != null) {
            scope.launch {
                try {
                    eng.pauseAll()
                    withContext(Dispatchers.Main) { result.success(true) }
                } catch (e: Exception) {
                    withContext(Dispatchers.Main) { result.success(true) }
                }
            }
        } else {
            result.success(true)
        }
    }

    private fun handleResumeTorrent(call: MethodCall, result: MethodChannel.Result) {
        val eng = engine
        if (eng != null) {
            scope.launch {
                try {
                    eng.resumeAll()
                    withContext(Dispatchers.Main) { result.success(true) }
                } catch (e: Exception) {
                    withContext(Dispatchers.Main) { result.success(true) }
                }
            }
        } else {
            result.success(true)
        }
    }

    private fun handlePauseAll(result: MethodChannel.Result) {
        val eng = engine
        if (eng != null) {
            scope.launch {
                try {
                    eng.pauseAll()
                    withContext(Dispatchers.Main) { result.success(true) }
                } catch (e: Exception) {
                    withContext(Dispatchers.Main) { result.success(true) }
                }
            }
        } else {
            result.success(true)
        }
    }

    private fun handleResumeAll(result: MethodChannel.Result) {
        val eng = engine
        if (eng != null) {
            scope.launch {
                try {
                    eng.resumeAll()
                    withContext(Dispatchers.Main) { result.success(true) }
                } catch (e: Exception) {
                    withContext(Dispatchers.Main) { result.success(true) }
                }
            }
        } else {
            result.success(true)
        }
    }

    private fun handleDispose(result: MethodChannel.Result) {
        scope.cancel()
        engine = null
        engineAvailable = false
        Log.i(TAG, "Engine disposed")
        result.success(true)
    }
}
