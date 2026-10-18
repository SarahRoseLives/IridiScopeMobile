package dev.sarahsforge.iridiscope

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.ConcurrentHashMap

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "IridiScope/Main"
        private const val FILE_CHANNEL = "dev.sarahsforge.iridiscope/files"
        private const val REQ_PICK_IQ = 7101
    }

    private var hackrf: HackRfBridge? = null
    private val openFiles = ConcurrentHashMap<Int, ParcelFileDescriptor>()
    private var pendingPick: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val bridge = HackRfBridge(applicationContext)
        hackrf = bridge
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "dev.sarahsforge.iridiscope/hackrf").setMethodCallHandler(bridge)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FILE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickIqFile" -> pickIqFile(result)
                    "openIqFile" -> openIqFile(call, result)
                    "closeIqFile" -> {
                        val fd = (call.argument<Any>("fd") as? Number)?.toInt() ?: -1
                        closeFd(fd)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun pickIqFile(result: MethodChannel.Result) {
        if (pendingPick != null) {
            result.error("BUSY", "File picker is already active", null)
            return
        }
        pendingPick = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        try {
            startActivityForResult(intent, REQ_PICK_IQ)
        } catch (t: Throwable) {
            pendingPick = null
            result.error("PICKER", t.message, null)
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQ_PICK_IQ) return
        val result = pendingPick
        pendingPick = null
        if (result == null) return

        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        try {
            try {
                contentResolver.takePersistableUriPermission(
                    uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
            } catch (_: Throwable) {
            }
            openUri(uri, result)
        } catch (t: Throwable) {
            Log.e(TAG, "pickIqFile failed", t)
            result.error("OPEN_FAILED", t.message, null)
        }
    }

    private fun openUri(uri: Uri, result: MethodChannel.Result) {
        val pfd = contentResolver.openFileDescriptor(uri, "r")
            ?: throw IllegalStateException("openFileDescriptor returned null")
        val fd = pfd.fd
        openFiles[fd] = pfd
        var name = uri.lastPathSegment ?: "iq-file"
        var size = try { pfd.statSize } catch (_: Throwable) { -1L }
        try {
            contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE),
                null, null, null
            )?.use { c ->
                if (c.moveToFirst()) {
                    val ni = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (ni >= 0 && !c.isNull(ni)) name = c.getString(ni)
                    val si = c.getColumnIndex(OpenableColumns.SIZE)
                    if (si >= 0 && !c.isNull(si)) size = c.getLong(si)
                }
            }
        } catch (_: Throwable) {
        }
        Log.i(TAG, "pickIqFile fd=$fd name=$name size=$size uri=$uri")
        result.success(mapOf("fd" to fd, "name" to name, "size" to size))
    }

    private fun openIqFile(call: io.flutter.plugin.common.MethodCall,
                           result: MethodChannel.Result) {
        val location = call.argument<String>("uri")
            ?: call.argument<String>("path")
        if (location.isNullOrBlank()) {
            result.error("BAD_ARGS", "uri/path required", null)
            return
        }
        try {
            val uri = Uri.parse(location)
            Log.i(TAG, "openIqFile location=$location scheme=${uri.scheme} path=${uri.path}")
            val pfd: ParcelFileDescriptor
            val name: String
            when (uri.scheme) {
                "content" -> {
                    pfd = contentResolver.openFileDescriptor(uri, "r")
                        ?: throw IllegalStateException("openFileDescriptor returned null")
                    name = call.argument<String>("name")
                        ?: uri.lastPathSegment ?: "iq-file"
                }
                "file" -> {
                    val path = uri.path
                        ?: throw IllegalArgumentException("file URI has no path")
                    val file = File(path)
                    pfd = ParcelFileDescriptor.open(
                        file, ParcelFileDescriptor.MODE_READ_ONLY)
                    name = call.argument<String>("name") ?: file.name
                }
                else -> {
                    val file = File(location)
                    pfd = ParcelFileDescriptor.open(
                        file, ParcelFileDescriptor.MODE_READ_ONLY)
                    name = call.argument<String>("name") ?: file.name
                }
            }
            val fd = pfd.fd
            openFiles[fd] = pfd
            val size = try { pfd.statSize } catch (_: Throwable) { -1L }
            result.success(mapOf("fd" to fd, "name" to name, "size" to size))
        } catch (t: Throwable) {
            Log.e(TAG, "openIqFile failed", t)
            result.error("OPEN_FAILED", t.message, null)
        }
    }

    private fun closeFd(fd: Int) {
        if (fd < 0) return
        openFiles.remove(fd)?.let {
            try { it.close() } catch (_: Throwable) {}
        }
    }

    override fun onDestroy() {
        hackrf?.dispose()
        hackrf = null
        for ((fd, _) in openFiles) closeFd(fd)
        super.onDestroy()
    }
}
