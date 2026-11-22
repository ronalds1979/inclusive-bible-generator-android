package com.ronalds1979.inclusivebible

import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognizerIntent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    companion object {
        private const val GEMINI_NANO_CHANNEL =
            "com.ronalds1979.inclusivebible/gemini_nano"
        private const val VOICE_INPUT_CHANNEL =
            "com.ronalds1979.inclusivebible/voice_input"
        private const val MEDIA_MUXER_CHANNEL =
            "com.ronalds1979.inclusivebible/media_muxer"
        private const val REQUEST_CODE_VOICE_VERSE = 4091
    }

    private var geminiNanoDescriber: GeminiNanoImageDescriber? = null
    private var pendingVoiceResult: MethodChannel.Result? = null
    private var pendingVoiceReturnList: Boolean = false
    private val muxExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.decorView.filterTouchesWhenObscured = true
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val describer = GeminiNanoImageDescriber(applicationContext).also {
            geminiNanoDescriber = it
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            GEMINI_NANO_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkAvailability" -> {
                    describer.checkAvailability { status ->
                        result.success(status)
                    }
                }
                "describeImage" -> {
                    val imageBytes = call.argument<ByteArray>("imageBytes")
                    val imagePath = call.argument<String>("imagePath")
                    val targetLanguage = call.argument<String>("targetLanguage")
                    describer.describeImage(
                        imageBytes = imageBytes,
                        imagePath = imagePath,
                        targetLanguage = targetLanguage,
                        onSuccess = { description -> result.success(description) },
                        onError = { code, message -> result.error(code, message, null) },
                    )
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            VOICE_INPUT_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> {
                    val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
                    val available = intent.resolveActivity(packageManager) != null
                    result.success(available)
                }
                "listenForVerse", "listenForVerseCandidates" -> {
                    if (pendingVoiceResult != null) {
                        result.error("busy", "Voice recognition is already active.", null)
                        return@setMethodCallHandler
                    }
                    val returnList = call.method == "listenForVerseCandidates"
                    val locale = call.argument<String>("locale") ?: "en-US"
                    val prompt = call.argument<String>("prompt") ?: ""
                    val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                        putExtra(
                            RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                            RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
                        )
                        putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
                        putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, locale)
                        putExtra(
                            RecognizerIntent.EXTRA_ONLY_RETURN_LANGUAGE_PREFERENCE,
                            true,
                        )
                        putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
                        if (prompt.isNotBlank()) {
                            putExtra(RecognizerIntent.EXTRA_PROMPT, prompt)
                        }
                    }
                    if (intent.resolveActivity(packageManager) == null) {
                        result.success(if (returnList) emptyList<String>() else null)
                        return@setMethodCallHandler
                    }
                    pendingVoiceResult = result
                    pendingVoiceReturnList = returnList
                    try {
                        @Suppress("DEPRECATION")
                        startActivityForResult(intent, REQUEST_CODE_VOICE_VERSE)
                    } catch (e: Exception) {
                        pendingVoiceResult = null
                        pendingVoiceReturnList = false
                        result.error(
                            "voice_error",
                            e.message ?: "Failed to start voice input.",
                            null,
                        )
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            MEDIA_MUXER_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "muxImageAndAudio" -> {
                    val imagePath = call.argument<String>("imagePath")
                    val audioPath = call.argument<String>("audioPath")
                    val outputPath = call.argument<String>("outputPath")
                    if (imagePath.isNullOrBlank() || audioPath.isNullOrBlank() || outputPath.isNullOrBlank()) {
                        result.error("invalid_args", "imagePath, audioPath, and outputPath are required.", null)
                        return@setMethodCallHandler
                    }
                    muxExecutor.execute {
                        try {
                            val muxedPath = VerseVideoMuxer.muxImageAndAudio(
                                imagePath = imagePath,
                                audioPath = audioPath,
                                outputPath = outputPath,
                            )
                            mainHandler.post { result.success(muxedPath) }
                        } catch (e: Throwable) {
                            mainHandler.post {
                                result.error(
                                    "mux_failed",
                                    e.message ?: "Failed to combine image and audio into MP4.",
                                    null,
                                )
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQUEST_CODE_VOICE_VERSE) {
            val callback = pendingVoiceResult
            val returnList = pendingVoiceReturnList
            pendingVoiceResult = null
            pendingVoiceReturnList = false
            if (callback != null) {
                if (resultCode == Activity.RESULT_OK) {
                    val matches = data?.getStringArrayListExtra(
                        RecognizerIntent.EXTRA_RESULTS,
                    )
                    if (returnList) {
                        callback.success(matches ?: arrayListOf<String>())
                    } else {
                        callback.success(matches?.firstOrNull())
                    }
                } else {
                    callback.success(if (returnList) emptyList<String>() else null)
                }
                return
            }
        }
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        pendingVoiceResult?.success(if (pendingVoiceReturnList) emptyList<String>() else null)
        pendingVoiceResult = null
        pendingVoiceReturnList = false
        geminiNanoDescriber?.close()
        geminiNanoDescriber = null
        muxExecutor.shutdownNow()
        super.onDestroy()
    }
}
