package com.ronalds1979.inclusivebible

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaCodecList
import android.media.MediaFormat
import android.media.MediaMuxer
import java.io.File
import java.io.RandomAccessFile
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Combines a still PNG/JPEG verse card image and a PCM WAV TTS narration file
 * into a single H.264 + AAC MP4 video using Android's built-in MediaCodec and
 * MediaMuxer (API 26+, zero third-party native dependencies).
 *
 * Sharing a single `video/mp4` via `ACTION_SEND` ensures messaging apps such
 * as WhatsApp preserve the visual verse card, playable TTS audio narration,
 * and accompanying Alt-Text/caption together.
 */
object VerseVideoMuxer {
    private const val VIDEO_MIME = MediaFormat.MIMETYPE_VIDEO_AVC
    private const val AUDIO_MIME = MediaFormat.MIMETYPE_AUDIO_AAC
    private const val VIDEO_FPS = 5
    private const val FRAME_DURATION_US = 1_000_000L / VIDEO_FPS
    private const val VIDEO_BITRATE = 1_500_000
    private const val I_FRAME_INTERVAL_SECONDS = 2
    private const val MAX_VIDEO_DIMENSION = 1280
    private const val MAX_IMAGE_BYTES = 20L * 1024L * 1024L
    private const val MAX_AUDIO_BYTES = 50L * 1024L * 1024L
    private const val MAX_IMAGE_DIMENSION = 16384
    private const val MAX_IMAGE_PIXELS = 64_000_000L
    private const val CODEC_TIMEOUT_US = 10_000L
    private const val TAIL_PADDING_US = 300_000L

    private data class WavInfo(
        val sampleRate: Int,
        val numChannels: Int,
        val bitsPerSample: Int,
        val dataOffset: Long,
        val dataSize: Long,
    ) {
        val bytesPerSecond: Long
            get() = sampleRate.toLong() * numChannels.toLong() * (bitsPerSample / 8).toLong()

        val durationUs: Long
            get() = if (bytesPerSecond > 0) (dataSize * 1_000_000L) / bytesPerSecond else 0L
    }

    private data class EncodedSample(
        val data: ByteArray,
        val presentationTimeUs: Long,
        val flags: Int,
    )

    private data class EncodedAudioTrack(
        val format: MediaFormat,
        val samples: List<EncodedSample>,
        val durationUs: Long,
    )

    private data class YuvFrame(
        val width: Int,
        val height: Int,
        val y: ByteArray,
        val u: ByteArray,
        val v: ByteArray,
    )

    fun muxImageAndAudio(
        imagePath: String,
        audioPath: String,
        outputPath: String,
    ): String {
        val imageFile = File(imagePath)
        val audioFile = File(audioPath)
        // 🛡️ Sentinel: Enforce regular-file and byte-size bounds before opening/decoding native media inputs
        require(imageFile.exists() && imageFile.isFile && imageFile.length() in 1L..MAX_IMAGE_BYTES) {
            "Image file does not exist or exceeds maximum allowed size."
        }
        require(audioFile.exists() && audioFile.isFile && audioFile.length() in 45L..MAX_AUDIO_BYTES) {
            "Audio file does not exist or exceeds maximum allowed size."
        }

        val outFile = File(outputPath)
        if (outFile.exists()) {
            outFile.delete()
        }

        try {
            val wav = parseWavHeader(audioFile)
            require(wav.durationUs > 0) { "Audio duration is zero." }

            val encodedAudio = encodeWavToAac(audioFile, wav)
            val yuvFrame = loadAndConvertImageToYuv(imageFile)
            val totalDurationUs = max(wav.durationUs, encodedAudio.durationUs) + TAIL_PADDING_US

            encodeVideoAndMux(
                yuvFrame = yuvFrame,
                encodedAudio = encodedAudio,
                totalDurationUs = totalDurationUs,
                outputPath = outputPath,
            )

            require(outFile.exists() && outFile.length() > 1024) {
                "Muxed MP4 output is missing or empty."
            }
            return outputPath
        } catch (e: Throwable) {
            if (outFile.exists()) {
                outFile.delete()
            }
            throw e
        }
    }

    private fun parseWavHeader(file: File): WavInfo {
        RandomAccessFile(file, "r").use { raf ->
            val header = ByteArray(12)
            raf.readFully(header)
            val riff = String(header, 0, 4, Charsets.US_ASCII)
            val wave = String(header, 8, 4, Charsets.US_ASCII)
            require(riff == "RIFF" && wave == "WAVE") {
                "Unsupported audio format (expected RIFF/WAVE)."
            }

            var audioFormat = -1
            var numChannels = -1
            var sampleRate = -1
            var bitsPerSample = -1
            var dataOffset = -1L
            var dataSize = -1L

            val chunkHeader = ByteArray(8)
            val fileLength = raf.length()
            while (raf.filePointer + 8 <= fileLength) {
                raf.readFully(chunkHeader)
                val chunkId = String(chunkHeader, 0, 4, Charsets.US_ASCII)
                val chunkSize = ByteBuffer.wrap(chunkHeader, 4, 4)
                    .order(ByteOrder.LITTLE_ENDIAN)
                    .int
                    .toLong() and 0xFFFFFFFFL
                val chunkStart = raf.filePointer

                when (chunkId) {
                    "fmt " -> {
                        val fmtLen = min(chunkSize, 16L).toInt()
                        require(fmtLen >= 16) { "Invalid WAV fmt chunk." }
                        val fmt = ByteArray(fmtLen)
                        raf.readFully(fmt)
                        val bb = ByteBuffer.wrap(fmt).order(ByteOrder.LITTLE_ENDIAN)
                        audioFormat = bb.short.toInt() and 0xFFFF
                        numChannels = bb.short.toInt() and 0xFFFF
                        sampleRate = bb.int
                        bb.int // byteRate
                        bb.short // blockAlign
                        bitsPerSample = bb.short.toInt() and 0xFFFF
                    }
                    "data" -> {
                        dataOffset = chunkStart
                        dataSize = min(chunkSize, fileLength - chunkStart)
                    }
                }

                // Chunks are padded to even byte boundaries.
                val nextPos = chunkStart + chunkSize + (chunkSize and 1L)
                if (nextPos > fileLength || nextPos <= chunkStart) {
                    break
                }
                raf.seek(nextPos)
            }

            require(audioFormat == 1) { "Only uncompressed PCM WAV is supported (got $audioFormat)." }
            require(bitsPerSample == 16) { "Only 16-bit PCM WAV is supported (got $bitsPerSample)." }
            require(numChannels in 1..2) { "Unsupported channel count: $numChannels." }
            require(sampleRate in 8000..48000) { "Unsupported sample rate: $sampleRate." }
            require(dataOffset > 0 && dataSize > 0) { "WAV data chunk not found." }

            return WavInfo(
                sampleRate = sampleRate,
                numChannels = numChannels,
                bitsPerSample = bitsPerSample,
                dataOffset = dataOffset,
                dataSize = dataSize,
            )
        }
    }

    private fun encodeWavToAac(audioFile: File, wav: WavInfo): EncodedAudioTrack {
        val bitrate = if (wav.numChannels == 1) 96_000 else 128_000
        val format = MediaFormat.createAudioFormat(AUDIO_MIME, wav.sampleRate, wav.numChannels).apply {
            setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
            setInteger(MediaFormat.KEY_BIT_RATE, bitrate)
            setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 16384)
        }

        val codec = MediaCodec.createEncoderByType(AUDIO_MIME)
        val samples = ArrayList<EncodedSample>()
        var outputFormat: MediaFormat? = null
        var lastPtsUs = 0L

        try {
            codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            codec.start()

            val bufferInfo = MediaCodec.BufferInfo()
            val bytesPerSecond = wav.bytesPerSecond
            var totalBytesRead = 0L
            var inputDone = false
            var outputDone = false

            RandomAccessFile(audioFile, "r").use { raf ->
                raf.seek(wav.dataOffset)

                while (!outputDone) {
                    if (!inputDone) {
                        val inputIndex = codec.dequeueInputBuffer(CODEC_TIMEOUT_US)
                        if (inputIndex >= 0) {
                            val inputBuffer = codec.getInputBuffer(inputIndex)!!
                            inputBuffer.clear()
                            val remainingFileBytes = wav.dataSize - totalBytesRead
                            if (remainingFileBytes <= 0) {
                                val ptsUs = (totalBytesRead * 1_000_000L) / bytesPerSecond
                                codec.queueInputBuffer(
                                    inputIndex,
                                    0,
                                    0,
                                    ptsUs,
                                    MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                                )
                                inputDone = true
                            } else {
                                val toRead = min(inputBuffer.remaining().toLong(), remainingFileBytes).toInt()
                                val chunk = ByteArray(toRead)
                                val bytesRead = raf.read(chunk, 0, toRead)
                                if (bytesRead <= 0) {
                                    val ptsUs = (totalBytesRead * 1_000_000L) / bytesPerSecond
                                    codec.queueInputBuffer(
                                        inputIndex,
                                        0,
                                        0,
                                        ptsUs,
                                        MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                                    )
                                    inputDone = true
                                } else {
                                    val ptsUs = (totalBytesRead * 1_000_000L) / bytesPerSecond
                                    inputBuffer.put(chunk, 0, bytesRead)
                                    totalBytesRead += bytesRead
                                    codec.queueInputBuffer(inputIndex, 0, bytesRead, ptsUs, 0)
                                }
                            }
                        }
                    }

                    val outputIndex = codec.dequeueOutputBuffer(bufferInfo, CODEC_TIMEOUT_US)
                    when {
                        outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                            outputFormat = codec.outputFormat
                        }
                        outputIndex >= 0 -> {
                            val isConfig = (bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) != 0
                            if (!isConfig && bufferInfo.size > 0) {
                                val outputBuffer = codec.getOutputBuffer(outputIndex)!!
                                outputBuffer.position(bufferInfo.offset)
                                outputBuffer.limit(bufferInfo.offset + bufferInfo.size)
                                val data = ByteArray(bufferInfo.size)
                                outputBuffer.get(data)
                                val ptsUs = max(bufferInfo.presentationTimeUs, lastPtsUs)
                                lastPtsUs = ptsUs
                                val cleanFlags = bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM.inv()
                                samples.add(EncodedSample(data, ptsUs, cleanFlags))
                            }
                            codec.releaseOutputBuffer(outputIndex, false)
                            if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                                outputDone = true
                            }
                        }
                    }
                }
            }
        } finally {
            try {
                codec.stop()
            } catch (_: Throwable) {
            }
            codec.release()
        }

        val finalFormat = requireNotNull(outputFormat) {
            "AAC encoder did not emit an output format."
        }
        require(samples.isNotEmpty()) { "AAC encoder produced no audio frames." }
        return EncodedAudioTrack(finalFormat, samples, lastPtsUs)
    }

    private fun loadAndConvertImageToYuv(imageFile: File): YuvFrame {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(imageFile.absolutePath, bounds)
        val srcWidth = bounds.outWidth
        val srcHeight = bounds.outHeight
        // 🛡️ Sentinel: Reject extreme-dimension or pixel-bomb images before native ARGB_8888 allocation
        require(
            srcWidth in 1..MAX_IMAGE_DIMENSION &&
                srcHeight in 1..MAX_IMAGE_DIMENSION &&
                srcWidth.toLong() * srcHeight.toLong() <= MAX_IMAGE_PIXELS,
        ) {
            "Image dimensions are invalid or exceed maximum allowed pixels."
        }

        // Compute target dimensions <= MAX_VIDEO_DIMENSION, multiples of 16 for H.264 compatibility.
        val scale = min(
            1.0,
            MAX_VIDEO_DIMENSION.toDouble() / max(srcWidth, srcHeight).toDouble(),
        )
        val targetWidth = alignTo16((srcWidth * scale).roundToInt())
        val targetHeight = alignTo16((srcHeight * scale).roundToInt())

        var sampleSize = 1
        while (srcWidth / (sampleSize * 2) >= targetWidth &&
            srcHeight / (sampleSize * 2) >= targetHeight
        ) {
            sampleSize *= 2
        }

        val decodeOpts = BitmapFactory.Options().apply {
            inPreferredConfig = Bitmap.Config.ARGB_8888
            inSampleSize = sampleSize
        }
        val decoded = requireNotNull(BitmapFactory.decodeFile(imageFile.absolutePath, decodeOpts)) {
            "Could not decode image bitmap."
        }
        val scaled = if (decoded.width == targetWidth && decoded.height == targetHeight) {
            decoded
        } else {
            Bitmap.createScaledBitmap(decoded, targetWidth, targetHeight, true).also {
                if (it !== decoded) decoded.recycle()
            }
        }

        val pixels = IntArray(targetWidth * targetHeight)
        scaled.getPixels(pixels, 0, targetWidth, 0, 0, targetWidth, targetHeight)
        scaled.recycle()

        val yPlane = ByteArray(targetWidth * targetHeight)
        val chromaWidth = targetWidth / 2
        val chromaHeight = targetHeight / 2
        val uPlane = ByteArray(chromaWidth * chromaHeight)
        val vPlane = ByteArray(chromaWidth * chromaHeight)

        // BT.601 full-to-video-range ARGB -> YUV420 conversion.
        for (row in 0 until targetHeight) {
            val rowOffset = row * targetWidth
            for (col in 0 until targetWidth) {
                val argb = pixels[rowOffset + col]
                val r = (argb shr 16) and 0xFF
                val g = (argb shr 8) and 0xFF
                val b = argb and 0xFF

                val y = ((66 * r + 129 * g + 25 * b + 128) shr 8) + 16
                yPlane[rowOffset + col] = y.coerceIn(0, 255).toByte()

                if ((row and 1) == 0 && (col and 1) == 0) {
                    val u = ((-38 * r - 74 * g + 112 * b + 128) shr 8) + 128
                    val v = ((112 * r - 94 * g - 18 * b + 128) shr 8) + 128
                    val chromaIdx = (row shr 1) * chromaWidth + (col shr 1)
                    uPlane[chromaIdx] = u.coerceIn(0, 255).toByte()
                    vPlane[chromaIdx] = v.coerceIn(0, 255).toByte()
                }
            }
        }

        return YuvFrame(targetWidth, targetHeight, yPlane, uPlane, vPlane)
    }

    private fun alignTo16(value: Int): Int {
        val aligned = ((value + 8) / 16) * 16
        return max(16, aligned)
    }

    private fun createAvcEncoder(preferSoftware: Boolean): MediaCodec {
        if (!preferSoftware) {
            return MediaCodec.createEncoderByType(VIDEO_MIME)
        }
        val list = MediaCodecList(MediaCodecList.REGULAR_CODECS)
        for (info in list.codecInfos) {
            if (!info.isEncoder) continue
            if (!info.supportedTypes.any { it.equals(VIDEO_MIME, ignoreCase = true) }) continue
            val name = info.name.lowercase()
            if (name.startsWith("c2.android.") || name.startsWith("omx.google.")) {
                return MediaCodec.createByCodecName(info.name)
            }
        }
        return MediaCodec.createEncoderByType(VIDEO_MIME)
    }

    private fun encodeVideoAndMux(
        yuvFrame: YuvFrame,
        encodedAudio: EncodedAudioTrack,
        totalDurationUs: Long,
        outputPath: String,
    ) {
        try {
            runVideoEncodeAndMux(
                yuvFrame = yuvFrame,
                encodedAudio = encodedAudio,
                totalDurationUs = totalDurationUs,
                outputPath = outputPath,
                preferSoftware = false,
            )
        } catch (hardwareError: Throwable) {
            val partial = File(outputPath)
            if (partial.exists()) partial.delete()
            // Retry once with the built-in Android software AVC encoder.
            runVideoEncodeAndMux(
                yuvFrame = yuvFrame,
                encodedAudio = encodedAudio,
                totalDurationUs = totalDurationUs,
                outputPath = outputPath,
                preferSoftware = true,
            )
        }
    }

    private fun runVideoEncodeAndMux(
        yuvFrame: YuvFrame,
        encodedAudio: EncodedAudioTrack,
        totalDurationUs: Long,
        outputPath: String,
        preferSoftware: Boolean,
    ) {
        val format = MediaFormat.createVideoFormat(VIDEO_MIME, yuvFrame.width, yuvFrame.height).apply {
            setInteger(
                MediaFormat.KEY_COLOR_FORMAT,
                MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible,
            )
            setInteger(MediaFormat.KEY_BIT_RATE, VIDEO_BITRATE)
            setInteger(MediaFormat.KEY_FRAME_RATE, VIDEO_FPS)
            setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, I_FRAME_INTERVAL_SECONDS)
        }

        val codec = createAvcEncoder(preferSoftware)
        var muxer: MediaMuxer? = null
        var muxerStarted = false
        var videoTrackIndex = -1
        var audioTrackIndex = -1

        try {
            codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            codec.start()

            muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            val totalFrames = max(2, ((totalDurationUs + FRAME_DURATION_US - 1) / FRAME_DURATION_US).toInt())
            val bufferInfo = MediaCodec.BufferInfo()
            var framesSubmitted = 0
            var inputDone = false
            var outputDone = false
            var lastVideoPtsUs = -1L

            while (!outputDone) {
                if (!inputDone) {
                    val inputIndex = codec.dequeueInputBuffer(CODEC_TIMEOUT_US)
                    if (inputIndex >= 0) {
                        if (framesSubmitted >= totalFrames) {
                            val eosPtsUs = framesSubmitted.toLong() * FRAME_DURATION_US
                            codec.queueInputBuffer(
                                inputIndex,
                                0,
                                0,
                                eosPtsUs,
                                MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                            )
                            inputDone = true
                        } else {
                            val bufferSize = codec.getInputBuffer(inputIndex)?.capacity()
                                ?: (yuvFrame.width * yuvFrame.height * 3 / 2)
                            val inputImage = codec.getInputImage(inputIndex)
                            if (inputImage != null) {
                                fillInputImage(inputImage, yuvFrame)
                            } else {
                                val buf = codec.getInputBuffer(inputIndex)!!
                                buf.clear()
                                buf.put(yuvFrame.y)
                                buf.put(yuvFrame.u)
                                buf.put(yuvFrame.v)
                            }
                            val ptsUs = framesSubmitted.toLong() * FRAME_DURATION_US
                            codec.queueInputBuffer(inputIndex, 0, bufferSize, ptsUs, 0)
                            framesSubmitted++
                        }
                    }
                }

                val outputIndex = codec.dequeueOutputBuffer(bufferInfo, CODEC_TIMEOUT_US)
                when {
                    outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        if (!muxerStarted) {
                            videoTrackIndex = muxer.addTrack(codec.outputFormat)
                            audioTrackIndex = muxer.addTrack(encodedAudio.format)
                            muxer.start()
                            muxerStarted = true
                        }
                    }
                    outputIndex >= 0 -> {
                        val isConfig = (bufferInfo.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) != 0
                        if (!isConfig && bufferInfo.size > 0 && muxerStarted) {
                            val outputBuffer = codec.getOutputBuffer(outputIndex)!!
                            outputBuffer.position(bufferInfo.offset)
                            outputBuffer.limit(bufferInfo.offset + bufferInfo.size)
                            if (bufferInfo.presentationTimeUs < lastVideoPtsUs) {
                                bufferInfo.presentationTimeUs = lastVideoPtsUs
                            }
                            lastVideoPtsUs = bufferInfo.presentationTimeUs
                            muxer.writeSampleData(videoTrackIndex, outputBuffer, bufferInfo)
                        }
                        codec.releaseOutputBuffer(outputIndex, false)
                        if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                            outputDone = true
                        }
                    }
                }
            }

            require(muxerStarted && audioTrackIndex >= 0) {
                "Video encoder did not emit an output format."
            }

            val audioInfo = MediaCodec.BufferInfo()
            for (sample in encodedAudio.samples) {
                audioInfo.offset = 0
                audioInfo.size = sample.data.size
                audioInfo.presentationTimeUs = sample.presentationTimeUs
                audioInfo.flags = sample.flags
                muxer.writeSampleData(audioTrackIndex, ByteBuffer.wrap(sample.data), audioInfo)
            }
        } finally {
            try {
                codec.stop()
            } catch (_: Throwable) {
            }
            codec.release()
            if (muxer != null) {
                if (muxerStarted) {
                    try {
                        muxer.stop()
                    } catch (_: Throwable) {
                    }
                }
                try {
                    muxer.release()
                } catch (_: Throwable) {
                }
            }
        }
    }

    private fun fillInputImage(image: android.media.Image, frame: YuvFrame) {
        val planes = image.planes
        copyPlane(
            src = frame.y,
            srcWidth = frame.width,
            srcHeight = frame.height,
            plane = planes[0],
        )
        copyPlane(
            src = frame.u,
            srcWidth = frame.width / 2,
            srcHeight = frame.height / 2,
            plane = planes[1],
        )
        copyPlane(
            src = frame.v,
            srcWidth = frame.width / 2,
            srcHeight = frame.height / 2,
            plane = planes[2],
        )
    }

    private fun copyPlane(
        src: ByteArray,
        srcWidth: Int,
        srcHeight: Int,
        plane: android.media.Image.Plane,
    ) {
        val buffer = plane.buffer
        val rowStride = plane.rowStride
        val pixelStride = plane.pixelStride

        if (pixelStride == 1 && rowStride == srcWidth) {
            buffer.position(0)
            buffer.put(src, 0, srcWidth * srcHeight)
            return
        }

        if (pixelStride == 1) {
            for (row in 0 until srcHeight) {
                buffer.position(row * rowStride)
                buffer.put(src, row * srcWidth, srcWidth)
            }
            return
        }

        for (row in 0 until srcHeight) {
            val srcRowOffset = row * srcWidth
            val dstRowOffset = row * rowStride
            for (col in 0 until srcWidth) {
                buffer.put(dstRowOffset + col * pixelStride, src[srcRowOffset + col])
            }
        }
    }
}
