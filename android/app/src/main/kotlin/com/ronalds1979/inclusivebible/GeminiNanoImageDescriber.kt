package com.ronalds1979.inclusivebible

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import com.google.common.util.concurrent.FutureCallback
import com.google.common.util.concurrent.Futures
import com.google.mlkit.common.model.DownloadConditions
import com.google.mlkit.genai.common.DownloadCallback
import com.google.mlkit.genai.common.FeatureStatus
import com.google.mlkit.genai.common.GenAiException
import com.google.mlkit.genai.imagedescription.ImageDescriber
import com.google.mlkit.genai.imagedescription.ImageDescriberOptions
import com.google.mlkit.genai.imagedescription.ImageDescription
import com.google.mlkit.genai.imagedescription.ImageDescriptionRequest
import com.google.mlkit.genai.imagedescription.ImageDescriptionResult
import com.google.mlkit.nl.translate.TranslateLanguage
import com.google.mlkit.nl.translate.Translation
import com.google.mlkit.nl.translate.Translator
import com.google.mlkit.nl.translate.TranslatorOptions
import java.io.File
import java.util.Locale
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors

/**
 * Wraps ML Kit's on-device GenAI Image Description API (Gemini Nano via AICore).
 * Runs 100% locally at zero cost with no API key on compatible Android devices.
 */
class GeminiNanoImageDescriber(private val appContext: Context) {
    companion object {
        private const val MAX_IMAGE_BYTES: Long = 20L * 1024L * 1024L
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private val ioExecutor = Executors.newSingleThreadExecutor()
    private val translators = ConcurrentHashMap<String, Translator>()

    @Volatile
    private var imageDescriber: ImageDescriber? = null

    private fun getOrCreateDescriber(): ImageDescriber {
        val existing = imageDescriber
        if (existing != null) return existing
        val options = ImageDescriberOptions.builder(appContext).build()
        return ImageDescription.getClient(options).also { imageDescriber = it }
    }

    private fun resolveTargetTranslateLanguage(targetLanguage: String?): String? {
        val normalized = targetLanguage?.trim()?.lowercase(Locale.ROOT).orEmpty()
        if (normalized.isEmpty() || normalized.startsWith("en")) return null
        if (normalized.startsWith("pt")) return TranslateLanguage.PORTUGUESE
        if (normalized.startsWith("es")) return TranslateLanguage.SPANISH
        val primaryTag = normalized.substringBefore('-').substringBefore('_')
        val resolved = TranslateLanguage.fromLanguageTag(primaryTag)
        return if (resolved == null || resolved == TranslateLanguage.ENGLISH) null else resolved
    }

    private fun getOrCreateTranslator(targetLang: String): Translator {
        return translators.computeIfAbsent(targetLang) { lang ->
            val options = TranslatorOptions.Builder()
                .setSourceLanguage(TranslateLanguage.ENGLISH)
                .setTargetLanguage(lang)
                .build()
            Translation.getClient(options)
        }
    }

    fun checkAvailability(onResult: (String) -> Unit) {
        try {
            val describer = getOrCreateDescriber()
            val statusFuture = describer.checkFeatureStatus()
            Futures.addCallback(
                statusFuture,
                object : FutureCallback<Int> {
                    override fun onSuccess(status: Int?) {
                        val mapped = when (status) {
                            FeatureStatus.AVAILABLE -> "available"
                            FeatureStatus.DOWNLOADABLE -> "downloadable"
                            FeatureStatus.DOWNLOADING -> "downloading"
                            else -> "unavailable"
                        }
                        mainHandler.post { onResult(mapped) }
                    }

                    override fun onFailure(t: Throwable) {
                        mainHandler.post { onResult("unavailable") }
                    }
                },
                ContextCompat.getMainExecutor(appContext),
            )
        } catch (_: Throwable) {
            mainHandler.post { onResult("unavailable") }
        }
    }

    fun describeImage(
        imageBytes: ByteArray?,
        imagePath: String?,
        targetLanguage: String? = null,
        onSuccess: (String) -> Unit,
        onError: (code: String, message: String) -> Unit,
    ) {
        val translateTargetLang = resolveTargetTranslateLanguage(targetLanguage)
        ioExecutor.execute {
            val bitmap = decodeSampledBitmap(imageBytes, imagePath, maxDimension = 1024)
            if (bitmap == null) {
                mainHandler.post {
                    onError("invalid_image", "Could not decode image for on-device description.")
                }
                return@execute
            }

            try {
                val describer = getOrCreateDescriber()
                val statusFuture = describer.checkFeatureStatus()
                Futures.addCallback(
                    statusFuture,
                    object : FutureCallback<Int> {
                        override fun onSuccess(status: Int?) {
                            when (status) {
                                FeatureStatus.AVAILABLE -> runInference(
                                    describer = describer,
                                    bitmap = bitmap,
                                    translateTargetLang = translateTargetLang,
                                    onSuccess = onSuccess,
                                    onError = onError,
                                )
                                FeatureStatus.DOWNLOADABLE -> {
                                    describer.downloadFeature(
                                        object : DownloadCallback {
                                            override fun onDownloadStarted(bytesToDownload: Long) {}

                                            override fun onDownloadProgress(totalBytesDownloaded: Long) {}

                                            override fun onDownloadCompleted() {
                                                runInference(
                                                    describer = describer,
                                                    bitmap = bitmap,
                                                    translateTargetLang = translateTargetLang,
                                                    onSuccess = onSuccess,
                                                    onError = onError,
                                                )
                                            }

                                            override fun onDownloadFailed(e: GenAiException) {
                                                bitmap.recycle()
                                                mainHandler.post {
                                                    onError(
                                                        "download_failed",
                                                        e.message ?: "Failed to download Gemini Nano model.",
                                                    )
                                                }
                                            }
                                        },
                                    )
                                }
                                FeatureStatus.DOWNLOADING -> {
                                    bitmap.recycle()
                                    mainHandler.post {
                                        onError(
                                            "downloading",
                                            "Gemini Nano model is currently downloading. Please try again shortly.",
                                        )
                                    }
                                }
                                else -> {
                                    bitmap.recycle()
                                    mainHandler.post {
                                        onError(
                                            "unavailable",
                                            "On-device Gemini Nano is not supported on this device.",
                                        )
                                    }
                                }
                            }
                        }

                        override fun onFailure(t: Throwable) {
                            bitmap.recycle()
                            mainHandler.post {
                                onError(
                                    "unavailable",
                                    t.message ?: "Failed to check Gemini Nano availability.",
                                )
                            }
                        }
                    },
                    ContextCompat.getMainExecutor(appContext),
                )
            } catch (t: Throwable) {
                bitmap.recycle()
                mainHandler.post {
                    onError(
                        "inference_error",
                        t.message ?: "Unexpected error running Gemini Nano.",
                    )
                }
            }
        }
    }

    private fun runInference(
        describer: ImageDescriber,
        bitmap: Bitmap,
        translateTargetLang: String?,
        onSuccess: (String) -> Unit,
        onError: (code: String, message: String) -> Unit,
    ) {
        try {
            val request = ImageDescriptionRequest.builder(bitmap).build()
            val resultFuture = describer.runInference(request)
            Futures.addCallback(
                resultFuture,
                object : FutureCallback<ImageDescriptionResult> {
                    override fun onSuccess(result: ImageDescriptionResult?) {
                        bitmap.recycle()
                        val text = result?.description?.trim().orEmpty()
                        if (text.isEmpty()) {
                            mainHandler.post {
                                onError("empty_result", "Gemini Nano returned an empty description.")
                            }
                        } else if (translateTargetLang != null) {
                            translateDescription(
                                englishText = text,
                                targetLang = translateTargetLang,
                                onSuccess = onSuccess,
                                onError = onError,
                            )
                        } else {
                            mainHandler.post { onSuccess(text) }
                        }
                    }

                    override fun onFailure(t: Throwable) {
                        bitmap.recycle()
                        mainHandler.post {
                            onError(
                                "inference_error",
                                t.message ?: "Failed to describe image on-device.",
                            )
                        }
                    }
                },
                ContextCompat.getMainExecutor(appContext),
            )
        } catch (t: Throwable) {
            bitmap.recycle()
            mainHandler.post {
                onError(
                    "inference_error",
                    t.message ?: "Failed to start Gemini Nano inference.",
                )
            }
        }
    }

    private fun translateDescription(
        englishText: String,
        targetLang: String,
        onSuccess: (String) -> Unit,
        onError: (code: String, message: String) -> Unit,
    ) {
        try {
            val translator = getOrCreateTranslator(targetLang)
            val conditions = DownloadConditions.Builder().build()
            translator.downloadModelIfNeeded(conditions)
                .addOnSuccessListener {
                    translator.translate(englishText)
                        .addOnSuccessListener { translated ->
                            val trimmed = translated.trim()
                            if (trimmed.isEmpty()) {
                                mainHandler.post {
                                    onError(
                                        "translation_failed",
                                        "On-device translator returned an empty description.",
                                    )
                                }
                            } else {
                                mainHandler.post { onSuccess(trimmed) }
                            }
                        }
                        .addOnFailureListener { e ->
                            mainHandler.post {
                                onError(
                                    "translation_failed",
                                    e.message ?: "Failed to translate image description on-device.",
                                )
                            }
                        }
                }
                .addOnFailureListener { e ->
                    mainHandler.post {
                        onError(
                            "translation_failed",
                            e.message ?: "Failed to download on-device translation model.",
                        )
                    }
                }
        } catch (t: Throwable) {
            mainHandler.post {
                onError(
                    "translation_failed",
                    t.message ?: "Unexpected error translating image description on-device.",
                )
            }
        }
    }

    private fun hasValidRasterHeader(header: ByteArray, length: Int): Boolean {
        if (length >= 4 &&
            header[0] == 0x89.toByte() &&
            header[1] == 0x50.toByte() &&
            header[2] == 0x4E.toByte() &&
            header[3] == 0x47.toByte()
        ) {
            return true
        }
        if (length >= 3 &&
            header[0] == 0xFF.toByte() &&
            header[1] == 0xD8.toByte() &&
            header[2] == 0xFF.toByte()
        ) {
            return true
        }
        if (length >= 12 &&
            header[0] == 0x52.toByte() &&
            header[1] == 0x49.toByte() &&
            header[2] == 0x46.toByte() &&
            header[3] == 0x46.toByte() &&
            header[8] == 0x57.toByte() &&
            header[9] == 0x45.toByte() &&
            header[10] == 0x42.toByte() &&
            header[11] == 0x50.toByte()
        ) {
            return true
        }
        return false
    }

    private fun decodeSampledBitmap(
        imageBytes: ByteArray?,
        imagePath: String?,
        maxDimension: Int,
    ): Bitmap? {
        val boundsOptions = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        if (imageBytes != null && imageBytes.isNotEmpty()) {
            if (imageBytes.size.toLong() > MAX_IMAGE_BYTES ||
                !hasValidRasterHeader(imageBytes, imageBytes.size)
            ) {
                return null
            }
            BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size, boundsOptions)
        } else if (!imagePath.isNullOrBlank()) {
            val file = File(imagePath)
            if (!file.exists() || !file.isFile) return null
            val fileSize = file.length()
            if (fileSize <= 0L || fileSize > MAX_IMAGE_BYTES) return null
            val header = ByteArray(12)
            val bytesRead = try {
                file.inputStream().use { it.read(header) }
            } catch (_: Throwable) {
                return null
            }
            if (!hasValidRasterHeader(header, bytesRead)) return null
            BitmapFactory.decodeFile(imagePath, boundsOptions)
        } else {
            return null
        }

        val width = boundsOptions.outWidth
        val height = boundsOptions.outHeight
        if (width <= 0 || height <= 0) return null

        var sampleSize = 1
        while (width / sampleSize > maxDimension || height / sampleSize > maxDimension) {
            sampleSize *= 2
        }

        val decodeOptions = BitmapFactory.Options().apply { inSampleSize = sampleSize }
        return if (imageBytes != null && imageBytes.isNotEmpty()) {
            BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size, decodeOptions)
        } else {
            BitmapFactory.decodeFile(imagePath, decodeOptions)
        }
    }

    fun close() {
        try {
            imageDescriber?.close()
        } catch (_: Throwable) {
        } finally {
            imageDescriber = null
            translators.values.forEach { translator ->
                try {
                    translator.close()
                } catch (_: Throwable) {
                }
            }
            translators.clear()
            ioExecutor.shutdown()
        }
    }
}
