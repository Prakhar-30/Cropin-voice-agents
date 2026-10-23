package com.cropin.cropin_voice_agents

import android.annotation.SuppressLint
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.speech.ModelDownloadListener
import android.speech.RecognitionSupport
import android.speech.RecognitionSupportCallback
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Manages Android's on-device speech models from inside the app, so field
 * users never have to open system settings:
 *  - "status":   which languages are installed / downloading / supported (API 33+)
 *  - "download": asks the on-device recogniser to fetch a language model
 *                (API 33+, with progress callbacks on API 34+)
 */
class MainActivity : FlutterActivity() {
    private val main = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "cropin/speech_packs")
        channel = ch
        ch.setMethodCallHandler { call, result ->
            val locale = call.argument<String>("locale") ?: "en-IN"
            when (call.method) {
                "status" -> status(locale, result)
                "download" -> download(locale, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun recognizerIntent(locale: String) =
        Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
        }

    private fun onDeviceAvailable(): Boolean =
        Build.VERSION.SDK_INT >= 31 && SpeechRecognizer.isOnDeviceRecognitionAvailable(this)

    @SuppressLint("NewApi")
    private fun status(locale: String, result: MethodChannel.Result) {
        val out = hashMapOf<String, Any>(
            "sdk" to Build.VERSION.SDK_INT,
            "onDeviceAvailable" to onDeviceAvailable(),
        )
        if (Build.VERSION.SDK_INT < 33 || !onDeviceAvailable()) {
            result.success(out)
            return
        }
        main.post {
            val recognizer = try {
                SpeechRecognizer.createOnDeviceSpeechRecognizer(this)
            } catch (e: Exception) {
                null
            }
            if (recognizer == null) {
                result.success(out)
                return@post
            }
            var replied = false
            fun reply() = main.post {
                if (!replied) {
                    replied = true
                    result.success(out)
                    recognizer.destroy()
                }
            }
            try {
                recognizer.checkRecognitionSupport(
                    recognizerIntent(locale), executor,
                    object : RecognitionSupportCallback {
                        override fun onSupportResult(support: RecognitionSupport) {
                            out["installed"] = support.installedOnDeviceLanguages
                            out["pending"] = support.pendingOnDeviceLanguages
                            out["supported"] = support.supportedOnDeviceLanguages
                            out["online"] = support.onlineLanguages
                            reply()
                        }

                        override fun onError(error: Int) {
                            out["error"] = error
                            reply()
                        }
                    })
            } catch (e: Exception) {
                out["error"] = -1
                reply()
            }
            // Never leave Dart waiting if the service doesn't answer.
            main.postDelayed({ if (!replied) reply() }, 6000)
        }
    }

    @SuppressLint("NewApi")
    private fun download(locale: String, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 33 || !onDeviceAvailable()) {
            result.success("unsupported")
            return
        }
        main.post {
            val recognizer = try {
                SpeechRecognizer.createOnDeviceSpeechRecognizer(this)
            } catch (e: Exception) {
                null
            }
            if (recognizer == null) {
                result.success("unsupported")
                return@post
            }
            if (Build.VERSION.SDK_INT >= 34) {
                var replied = false
                fun reply(value: String) = main.post {
                    if (!replied) {
                        replied = true
                        result.success(value)
                    }
                }
                fun progress(percent: Int) = main.post {
                    channel?.invokeMethod("progress", mapOf("locale" to locale, "percent" to percent))
                }
                try {
                    recognizer.triggerModelDownload(
                        recognizerIntent(locale), executor,
                        object : ModelDownloadListener {
                            override fun onProgress(completedPercent: Int) = progress(completedPercent).let { }

                            override fun onSuccess() {
                                progress(100)
                                reply("success")
                                main.post { recognizer.destroy() }
                            }

                            override fun onScheduled() = reply("scheduled").let { }

                            override fun onError(error: Int) {
                                reply("error:$error")
                                main.post { recognizer.destroy() }
                            }
                        })
                } catch (e: Exception) {
                    reply("error:${e.message}")
                }
            } else {
                try {
                    recognizer.triggerModelDownload(recognizerIntent(locale))
                    result.success("triggered")
                } catch (e: Exception) {
                    result.success("error:${e.message}")
                }
            }
        }
    }
}
