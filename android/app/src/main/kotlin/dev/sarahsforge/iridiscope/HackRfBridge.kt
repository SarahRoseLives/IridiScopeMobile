package dev.sarahsforge.iridiscope

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.mantz_it.hackrf_android.Hackrf
import com.mantz_it.hackrf_android.HackrfCallbackInterface
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Owns the HackRF USB device and feeds IQ directly into libiridiscope.so.
 *
 * IQ never crosses the Flutter event channel: the USB receive queue is drained
 * on a dedicated thread and each packet is passed to the native pipeline via
 * JNI. Dart only receives spectrum frames and decoded messages.
 */
class HackRfBridge(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "IridiScope/HackRF"
        private const val CHANNEL = "dev.sarahsforge.iridiscope/hackrf"
    }

    private external fun nativeFeedIq(data: ByteArray)

    private val mainHandler = Handler(Looper.getMainLooper())
    private val io = Executors.newSingleThreadExecutor { r ->
        Thread(r, "hackrf-control").apply { isDaemon = true }
    }

    private var hackrf: Hackrf? = null
    private var pendingInit: MethodChannel.Result? = null
    private var rxQueue: ArrayBlockingQueue<ByteArray>? = null
    private var feedThread: Thread? = null
    private val feedRunning = AtomicBoolean(false)

    @Volatile private var sampleRate = 2_400_000

    private val callback = object : HackrfCallbackInterface {
        override fun onHackrfReady(device: Hackrf) {
            Log.i(TAG, "HackRF ready")
            hackrf = device
            val r = pendingInit
            pendingInit = null
            if (r != null) mainHandler.post { r.success(true) }
        }

        override fun onHackrfError(message: String) {
            Log.e(TAG, "HackRF init failed: $message")
            hackrf = null
            val r = pendingInit
            pendingInit = null
            if (r != null) mainHandler.post { r.error("HACKRF", message, null) }
        }
    }

    private val detachReceiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context?, intent: Intent?) {
            if (intent?.action == UsbManager.ACTION_USB_DEVICE_DETACHED) {
                Log.w(TAG, "HackRF detached")
                stopInternal()
                hackrf = null
            }
        }
    }

    private var nativeLoaded = false

    init {
        try {
            System.loadLibrary("iridiscope")
            nativeLoaded = true
        } catch (t: Throwable) {
            Log.e(TAG, "Could not load libiridiscope.so", t)
        }
        try {
            context.registerReceiver(detachReceiver, IntentFilter(UsbManager.ACTION_USB_DEVICE_DETACHED))
        } catch (t: Throwable) {
            Log.w(TAG, "Could not register USB detach receiver", t)
        }
    }

    fun dispose() {
        stopInternal()
        try {
            context.unregisterReceiver(detachReceiver)
        } catch (_: Throwable) {
        }
        io.shutdownNow()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "init" -> init(result)
            "configure" -> configure(call, result)
            "start" -> start(result)
            "stop" -> { stopInternal(); result.success(true) }
            "close" -> { stopInternal(); hackrf?.close(); hackrf = null; result.success(true) }
            "setFrequency" -> command(result) { h ->
                h.setFrequency(number(call, "hz").toLong())
            }
            "setSampleRate" -> command(result) { h ->
                val rate = number(call, "hz").toInt()
                h.setSampleRate(rate, 1)
                h.setBasebandFilterBandwidth(Hackrf.computeBasebandFilterBandwidth(rate))
                sampleRate = rate
                true
            }
            "setLna" -> command(result) { h -> h.setRxLNAGain(number(call, "gain").toInt()) }
            "setVga" -> command(result) { h -> h.setRxVGAGain(number(call, "gain").toInt()) }
            "setAmp" -> command(result) { h -> h.setAmp(boolean(call, "on")) }
            "setBiasTee" -> command(result) { h -> h.setAntennaPower(boolean(call, "on")) }
            "getBoardId" -> {
                val h = hackrf
                if (h == null) result.error("NOT_READY", "HackRF is not open", null)
                else result.success(h.boardID.toInt())
            }
            else -> result.notImplemented()
        }
    }

    private fun number(call: MethodCall, key: String): Number =
        (call.argument<Any>(key) as? Number) ?: 0

    private fun boolean(call: MethodCall, key: String): Boolean =
        when (val v = call.argument<Any>(key)) {
            is Boolean -> v
            is Number -> v.toInt() != 0
            else -> false
        }

    private fun init(result: MethodChannel.Result) {
        if (hackrf != null) {
            result.success(true)
            return
        }
        if (pendingInit != null) {
            result.error("BUSY", "HackRF init already in progress", null)
            return
        }
        if (!nativeLoaded) {
            result.error("NATIVE", "libiridiscope.so failed to load", null)
            return
        }
        pendingInit = result
        val ok = Hackrf.initHackrf(context, callback, 10)
        if (!ok) {
            pendingInit = null
            result.error("NOT_FOUND", "No HackRF device found", null)
        }
    }

    private fun configure(call: MethodCall, result: MethodChannel.Result) {
        io.execute {
            try {
                val h = hackrf ?: throw IllegalStateException("HackRF is not open")
                val hz = number(call, "hz").toLong()
                val rate = number(call, "sampleRate").toInt()
                val lna = number(call, "lna").toInt()
                val vga = number(call, "vga").toInt()
                val amp = number(call, "amp").toInt() != 0
                val bias = number(call, "biasTee").toInt() != 0

                h.stop()
                h.setSampleRate(rate, 1)
                h.setBasebandFilterBandwidth(Hackrf.computeBasebandFilterBandwidth(rate))
                h.setFrequency(hz)
                h.setRxLNAGain(lna)
                h.setRxVGAGain(vga)
                h.setAmp(amp)
                h.setAntennaPower(bias)
                sampleRate = rate
                mainHandler.post { result.success(true) }
            } catch (t: Throwable) {
                mainHandler.post { result.error("HACKRF", t.message, null) }
            }
        }
    }

    private fun command(result: MethodChannel.Result, block: (Hackrf) -> Boolean) {
        io.execute {
            try {
                val h = hackrf ?: throw IllegalStateException("HackRF is not open")
                val ok = block(h)
                mainHandler.post { result.success(ok) }
            } catch (t: Throwable) {
                mainHandler.post { result.error("HACKRF", t.message, null) }
            }
        }
    }

    private fun start(result: MethodChannel.Result) {
        io.execute {
            try {
                if (feedRunning.get()) {
                    mainHandler.post { result.success(true) }
                    return@execute
                }
                val h = hackrf ?: throw IllegalStateException("HackRF is not open")
                val q = h.startRX() ?: throw IllegalStateException("startRX failed")
                rxQueue = q
                feedRunning.set(true)
                val t = Thread({ feedLoop(q) }, "hackrf-rx")
                t.isDaemon = true
                feedThread = t
                t.start()
                Log.i(TAG, "HackRF RX started at $sampleRate Hz")
                mainHandler.post { result.success(true) }
            } catch (t: Throwable) {
                feedRunning.set(false)
                mainHandler.post { result.error("HACKRF", t.message, null) }
            }
        }
    }

    private fun feedLoop(q: ArrayBlockingQueue<ByteArray>) {
        while (feedRunning.get()) {
            try {
                val packet = q.poll(200, TimeUnit.MILLISECONDS) ?: continue
                if (packet.size >= 2) {
                    nativeFeedIq(packet)
                }
            } catch (_: InterruptedException) {
                break
            } catch (t: Throwable) {
                Log.e(TAG, "RX feed failed", t)
                break
            }
        }
    }

    private fun stopInternal() {
        feedRunning.set(false)
        feedThread?.interrupt()
        try {
            feedThread?.join(1500)
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
        }
        feedThread = null
        rxQueue = null
        try {
            hackrf?.stop()
        } catch (t: Throwable) {
            Log.w(TAG, "HackRF stop failed", t)
        }
    }
}
