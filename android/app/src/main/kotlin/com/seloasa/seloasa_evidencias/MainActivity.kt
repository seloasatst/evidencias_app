package com.seloasa.seloasa_evidencias

import android.view.WindowManager
import android.app.DownloadManager
import android.net.Uri
import android.os.Environment
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.seloasa.seloasa_evidencias/security"
    private val UPDATE_CHANNEL = "com.seloasa.seloasa_evidencias/update"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableSecure" -> {
                    try {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                "disableSecure" -> {
                    try {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPDATE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "downloadUpdate" -> {
                    val url = call.argument<String>("url")
                    val filename = call.argument<String>("filename") ?: "oneroute-update.apk"
                    if (url.isNullOrBlank()) {
                        result.error("INVALID_URL", "La URL de actualización está vacía", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val request = DownloadManager.Request(Uri.parse(url))
                            .setTitle("Actualización de One Route")
                            .setDescription("Descargando actualización en segundo plano")
                            .setMimeType("application/vnd.android.package-archive")
                            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
                            .setAllowedOverMetered(true)
                            .setAllowedOverRoaming(false)
                            .setDestinationInExternalFilesDir(
                                this,
                                Environment.DIRECTORY_DOWNLOADS,
                                filename,
                            )
                        val downloadId = getSystemService(DownloadManager::class.java).enqueue(request)
                        result.success(downloadId)
                    } catch (error: Exception) {
                        result.error("DOWNLOAD_ERROR", error.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}