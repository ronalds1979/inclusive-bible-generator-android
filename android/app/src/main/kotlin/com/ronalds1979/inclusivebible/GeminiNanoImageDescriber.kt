package com.ronalds1979.inclusivebible

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import com.google.common.util.concurrent.FutureCallback
import com.google.common.util.concurrent.Futures
import com.google.mlkit.genai.common.DownloadCallback
import com.google.mlkit.genai.common.FeatureStatus
import com.google.mlkit.genai.common.GenAiException
import com.google.mlkit.genai.imagedescription.ImageDescriber
import com.google.mlkit.genai.imagedescription.ImageDescriberOptions
import com.google.mlkit.genai.imagedescription.ImageDescription
import com.google.mlkit.genai.imagedescription.ImageDescriptionRequest
import com.google.mlkit.genai.imagedescription.ImageDescriptionResult
import java.io.File
import java.util.concurrent.Executors

/**
 * Wraps ML Kit's on-device GenAI Image Description API (Gemini Nano via AICore).
 * Runs 100% locally at zero cost with no API key on compatible Android devices.
 */
class GeminiNanoImageDescriber(private val appContext: Context) {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val ioExecutor = Executors.newSingleThreadExecutor()

    @Volatile
    private var imageDescriber: ImageDescriber? = null

    private fun getOrCreateDescriber(): ImageDescriber {
        val existing = imageDescriber
        if (existing != null) return existing
        val options = ImageDescriberOptions.builder(appContext).build()
        return ImageDescription.getClient(options).also { imageDescriber = it }
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
        onSuccess: (String) -> Unit,
        onError: (code: String, message: String) -> Unit,
    ) {
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

    private fun decodeSampledBitmap(
        imageBytes: ByteArray?,
        imagePath: String?,
        maxDimension: Int,
    ): Bitmap? {
        val boundsOptions = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        if (imageBytes != null && imageBytes.isNotEmpty()) {
            BitmapFactory.decodeByteArray(imageBytes, 0, imageBytes.size, boundsOptions)
        } else if (!imagePath.isNullOrBlank()) {
            val file = File(imagePath)
            if (!file.exists() || !file.isFile) return null
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
            ioExecutor.shutdown()
        }
    }
}
