package com.rhythmix.rhythmix_native

import android.graphics.Bitmap
import android.graphics.Matrix
import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.nio.ByteOrder
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Décodage vidéo natif pour Rhythmix Golf (Android).
 * - info : dimensions affichées, cadence, durée, nombre d'images
 * - frames : images exactes (par index) en niveaux de gris + miniatures RGBA
 * - preview : une image en JPEG pour l'aperçu
 * - audioEnvelope : amplitude max par fenêtre de 10 ms (bruit d'impact)
 */
class RhythmixNativePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private val work: ExecutorService = Executors.newSingleThreadExecutor()
    private val previewWork: ExecutorService = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var previewRetriever: MediaMetadataRetriever? = null
    private var previewPath: String? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val ch = MethodChannel(binding.binaryMessenger, "rhythmix_native")
        ch.setMethodCallHandler(this)
        channel = ch
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        previewWork.execute { releasePreview() }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        if (path == null) {
            result.error("args", "Chemin de la vidéo manquant", null)
            return
        }
        val exec = if (call.method == "preview") previewWork else work
        exec.execute {
            try {
                val out: Any? = when (call.method) {
                    "info" -> info(path)
                    "frames" -> frames(path, call)
                    "preview" -> preview(path, call)
                    "audioEnvelope" -> audioEnvelope(path)
                    else -> {
                        main.post { result.notImplemented() }
                        return@execute
                    }
                }
                main.post { result.success(out) }
            } catch (e: Throwable) {
                main.post { result.error("native", e.message ?: e.toString(), null) }
            }
        }
    }

    // ---------- Utilitaires ----------

    private fun argInt(call: MethodCall, key: String, def: Int = 0): Int =
        (call.argument<Any>(key) as? Number)?.toInt() ?: def

    private fun argDouble(call: MethodCall, key: String, def: Double): Double =
        (call.argument<Any>(key) as? Number)?.toDouble() ?: def

    private fun metaInt(r: MediaMetadataRetriever, key: Int): Int =
        r.extractMetadata(key)?.trim()?.toDoubleOrNull()?.toInt() ?: 0

    /** Tourne l'image si le décodeur ne l'a pas déjà fait (vidéos de téléphone en portrait). */
    private fun orient(bm: Bitmap, rot: Int, codedW: Int, codedH: Int): Bitmap {
        if ((rot == 90 || rot == 270) && codedW != codedH) {
            val codedLandscape = codedW > codedH
            val bmLandscape = bm.width > bm.height
            if (codedLandscape == bmLandscape) {
                val m = Matrix()
                m.postRotate(rot.toFloat())
                return Bitmap.createBitmap(bm, 0, 0, bm.width, bm.height, m, true)
            }
        }
        return bm
    }

    /** Réduction par moitiés successives (moins de bruit), puis à la taille exacte. */
    private fun shrink(src: Bitmap, w: Int, h: Int): Bitmap {
        var b = src
        while (b.width / 2 >= w && b.height / 2 >= h && b.width >= 2 && b.height >= 2) {
            b = Bitmap.createScaledBitmap(
                b,
                max(1, (b.width / 2.0).roundToInt()),
                max(1, (b.height / 2.0).roundToInt()),
                true
            )
        }
        if (b.width != w || b.height != h) b = Bitmap.createScaledBitmap(b, w, h, true)
        return b
    }

    private fun writeGray(b: Bitmap, out: ByteArray, off: Int) {
        val w = b.width
        val h = b.height
        val px = IntArray(w * h)
        b.getPixels(px, 0, w, 0, 0, w, h)
        for (i in px.indices) {
            val p = px[i]
            val v = 0.3 * ((p shr 16) and 0xff) + 0.59 * ((p shr 8) and 0xff) + 0.11 * (p and 0xff)
            out[off + i] = min(255, v.toInt()).toByte()
        }
    }

    private fun writeRgba(b: Bitmap, out: ByteArray, off: Int) {
        val w = b.width
        val h = b.height
        val px = IntArray(w * h)
        b.getPixels(px, 0, w, 0, 0, w, h)
        for (i in px.indices) {
            val p = px[i]
            val o = off + i * 4
            out[o] = ((p shr 16) and 0xff).toByte()
            out[o + 1] = ((p shr 8) and 0xff).toByte()
            out[o + 2] = (p and 0xff).toByte()
            out[o + 3] = 0xff.toByte()
        }
    }

    // ---------- info ----------

    private fun info(path: String): Map<String, Any> {
        val r = MediaMetadataRetriever()
        try {
            r.setDataSource(path)
            val w = metaInt(r, MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
            val h = metaInt(r, MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
            val rot = metaInt(r, MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
            val durMs = metaInt(r, MediaMetadataRetriever.METADATA_KEY_DURATION).toDouble()
            val count = if (Build.VERSION.SDK_INT >= 28)
                metaInt(r, MediaMetadataRetriever.METADATA_KEY_VIDEO_FRAME_COUNT) else 0

            var fps = 0.0
            var vdurUs = 0L
            val ex = MediaExtractor()
            try {
                ex.setDataSource(path)
                for (i in 0 until ex.trackCount) {
                    val f = ex.getTrackFormat(i)
                    val mime = f.getString(MediaFormat.KEY_MIME) ?: ""
                    if (mime.startsWith("video/")) {
                        if (f.containsKey(MediaFormat.KEY_DURATION)) vdurUs = f.getLong(MediaFormat.KEY_DURATION)
                        if (f.containsKey(MediaFormat.KEY_FRAME_RATE)) {
                            fps = try {
                                f.getInteger(MediaFormat.KEY_FRAME_RATE).toDouble()
                            } catch (e: Exception) {
                                try { f.getFloat(MediaFormat.KEY_FRAME_RATE).toDouble() } catch (e2: Exception) { 0.0 }
                            }
                        }
                        break
                    }
                }
            } catch (e: Exception) {
            } finally {
                ex.release()
            }
            // Cadence réelle = nombre d'images / durée de la piste vidéo (comme la version web).
            if (count > 0 && vdurUs > 0) fps = count / (vdurUs / 1e6)
            else if (count > 0 && durMs > 0 && fps <= 0) fps = count / (durMs / 1000.0)

            val swap = rot == 90 || rot == 270
            return mapOf(
                "width" to (if (swap) h else w),
                "height" to (if (swap) w else h),
                "fps" to fps,
                "durationMs" to (if (vdurUs > 0) vdurUs / 1000.0 else durMs),
                "frameCount" to count
            )
        } finally {
            r.release()
        }
    }

    // ---------- frames ----------

    private fun frames(path: String, call: MethodCall): Map<String, Any> {
        val start = argInt(call, "start")
        val count = argInt(call, "count")
        val aw = argInt(call, "aw", 1)
        val ah = argInt(call, "ah", 1)
        val tw = argInt(call, "tw", 1)
        val th = argInt(call, "th", 1)
        val fps = argDouble(call, "fps", 30.0)
        val frameCount = argInt(call, "frameCount")
        val gray = ByteArray(max(0, count * aw * ah))
        val rgba = ByteArray(max(0, count * tw * th * 4))
        val r = MediaMetadataRetriever()
        try {
            r.setDataSource(path)
            val rot = metaInt(r, MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
            val codedW = metaInt(r, MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
            val codedH = metaInt(r, MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
            // Lots limités à ~120 Mo d'images décodées (4K = quelques images par lot).
            val perFrame = max(1L, codedW.toLong() * codedH.toLong() * 2L)
            val chunk = max(1, min(count, (120_000_000L / perFrame).toInt()))
            var k = 0
            while (k < count) {
                val c = min(chunk, count - k)
                var list: List<Bitmap>? = null
                if (Build.VERSION.SDK_INT >= 28 && frameCount > 0 && start + k < frameCount) {
                    val cc = min(c, frameCount - (start + k))
                    list = try {
                        val p = MediaMetadataRetriever.BitmapParams()
                        p.preferredConfig = Bitmap.Config.RGB_565
                        r.getFramesAtIndex(start + k, cc, p)
                    } catch (e: Exception) {
                        null
                    }
                }
                for (j in 0 until c) {
                    val idx = k + j
                    var bm: Bitmap? = list?.getOrNull(j)
                    if (bm == null) {
                        val tUs = ((start + idx + 0.5) / fps * 1_000_000.0).toLong()
                        bm = try {
                            r.getFrameAtTime(tUs, MediaMetadataRetriever.OPTION_CLOSEST)
                        } catch (e: Exception) {
                            null
                        }
                    }
                    if (bm != null) {
                        val big = shrink(orient(bm, rot, codedW, codedH), aw, ah)
                        writeGray(big, gray, idx * aw * ah)
                        val small = Bitmap.createScaledBitmap(big, tw, th, true)
                        writeRgba(small, rgba, idx * tw * th * 4)
                    }
                }
                list?.forEach { if (!it.isRecycled) it.recycle() }
                k += c
            }
        } finally {
            r.release()
        }
        return mapOf("gray" to gray, "rgba" to rgba)
    }

    // ---------- preview ----------

    private fun releasePreview() {
        try {
            previewRetriever?.release()
        } catch (e: Exception) {
        }
        previewRetriever = null
        previewPath = null
    }

    private fun preview(path: String, call: MethodCall): ByteArray? {
        val index = argInt(call, "index")
        val fps = argDouble(call, "fps", 30.0)
        val frameCount = argInt(call, "frameCount")
        val maxH = max(64, argInt(call, "maxH", 720))
        if (previewPath != path || previewRetriever == null) {
            releasePreview()
            val nr = MediaMetadataRetriever()
            nr.setDataSource(path)
            previewRetriever = nr
            previewPath = path
        }
        val r = previewRetriever ?: return null
        val rot = metaInt(r, MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
        val codedW = metaInt(r, MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
        val codedH = metaInt(r, MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
        var bm: Bitmap? = null
        if (Build.VERSION.SDK_INT >= 28 && frameCount > 0 && index < frameCount) {
            bm = try {
                r.getFrameAtIndex(index)
            } catch (e: Exception) {
                null
            }
        }
        if (bm == null) {
            bm = r.getFrameAtTime(((index + 0.5) / fps * 1_000_000.0).toLong(), MediaMetadataRetriever.OPTION_CLOSEST)
        }
        if (bm == null) return null
        var o = orient(bm, rot, codedW, codedH)
        if (o.height > maxH) {
            o = Bitmap.createScaledBitmap(o, max(1, (o.width * maxH.toDouble() / o.height).roundToInt()), maxH, true)
        }
        val bos = ByteArrayOutputStream()
        o.compress(Bitmap.CompressFormat.JPEG, 85, bos)
        return bos.toByteArray()
    }

    // ---------- audioEnvelope ----------

    private fun audioEnvelope(path: String): Map<String, Any>? {
        val ex = MediaExtractor()
        var codec: MediaCodec? = null
        try {
            ex.setDataSource(path)
            var track = -1
            var fmt: MediaFormat? = null
            for (i in 0 until ex.trackCount) {
                val f = ex.getTrackFormat(i)
                if ((f.getString(MediaFormat.KEY_MIME) ?: "").startsWith("audio/")) {
                    track = i
                    fmt = f
                    break
                }
            }
            if (track < 0 || fmt == null) return null
            ex.selectTrack(track)
            val mime = fmt.getString(MediaFormat.KEY_MIME) ?: return null
            val dec = MediaCodec.createDecoderByType(mime)
            codec = dec
            dec.configure(fmt, null, null, 0)
            dec.start()

            var sr = if (fmt.containsKey(MediaFormat.KEY_SAMPLE_RATE)) fmt.getInteger(MediaFormat.KEY_SAMPLE_RATE) else 44100
            var ch = if (fmt.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) fmt.getInteger(MediaFormat.KEY_CHANNEL_COUNT) else 1
            var win = max(1, (sr / 100.0).roundToInt())
            var pcmFloat = false
            val env = ArrayList<Double>()
            var cur = 0.0
            var cnt = 0
            val info = MediaCodec.BufferInfo()
            var inDone = false
            var outDone = false
            var idle = 0

            while (!outDone && idle < 500) {
                if (!inDone) {
                    val ii = dec.dequeueInputBuffer(10_000)
                    if (ii >= 0) {
                        val buf = dec.getInputBuffer(ii)
                        val sz = if (buf != null) ex.readSampleData(buf, 0) else -1
                        if (sz < 0) {
                            dec.queueInputBuffer(ii, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inDone = true
                        } else {
                            dec.queueInputBuffer(ii, 0, sz, ex.sampleTime, 0)
                            ex.advance()
                        }
                    }
                }
                val oi = dec.dequeueOutputBuffer(info, 10_000)
                when {
                    oi == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        val of = dec.outputFormat
                        if (of.containsKey(MediaFormat.KEY_SAMPLE_RATE)) sr = of.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                        if (of.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) ch = max(1, of.getInteger(MediaFormat.KEY_CHANNEL_COUNT))
                        win = max(1, (sr / 100.0).roundToInt())
                        if (Build.VERSION.SDK_INT >= 24 && of.containsKey(MediaFormat.KEY_PCM_ENCODING)) {
                            pcmFloat = of.getInteger(MediaFormat.KEY_PCM_ENCODING) == AudioFormat.ENCODING_PCM_FLOAT
                        }
                        idle = 0
                    }
                    oi >= 0 -> {
                        idle = 0
                        val ob = dec.getOutputBuffer(oi)
                        if (ob != null && info.size > 0) {
                            ob.position(info.offset)
                            ob.limit(info.offset + info.size)
                            val bb = ob.slice().order(ByteOrder.nativeOrder())
                            if (pcmFloat) {
                                val fb = bb.asFloatBuffer()
                                var s = 0
                                val total = fb.remaining()
                                while (s < total) {
                                    val v = abs(fb.get(s).toDouble())
                                    if (v > cur) cur = v
                                    cnt++
                                    if (cnt == win) { env.add(cur); cur = 0.0; cnt = 0 }
                                    s += ch
                                }
                            } else {
                                val sb = bb.asShortBuffer()
                                var s = 0
                                val total = sb.remaining()
                                while (s < total) {
                                    val v = abs(sb.get(s).toInt()) / 32768.0
                                    if (v > cur) cur = v
                                    cnt++
                                    if (cnt == win) { env.add(cur); cur = 0.0; cnt = 0 }
                                    s += ch
                                }
                            }
                        }
                        dec.releaseOutputBuffer(oi, false)
                        if ((info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) outDone = true
                    }
                    else -> if (inDone) idle++
                }
            }
            return mapOf("env" to env.toDoubleArray())
        } catch (e: Exception) {
            return null
        } finally {
            try { codec?.stop() } catch (e: Exception) {}
            try { codec?.release() } catch (e: Exception) {}
            ex.release()
        }
    }
}
