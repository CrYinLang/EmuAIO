package com.cryinlang.emuaio

import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream

class MainActivity : FlutterActivity() {

    private val CHANNEL = "content_uri_reader"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->

                if (call.method == "copyContentUriToCache") {
                    val uriStr = call.argument<String>("uri")

                    if (uriStr == null) {
                        result.error("NO_URI", "URI is null", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val uri = Uri.parse(uriStr)
                        val inputStream = contentResolver.openInputStream(uri)

                        if (inputStream == null) {
                            result.error("OPEN_FAILED", "Cannot open InputStream", null)
                            return@setMethodCallHandler
                        }

                        val fileName = "shared_${System.currentTimeMillis()}.zip"
                        val outputFile = File(cacheDir, fileName)

                        copyStreamToFile(inputStream, outputFile)

                        result.success(outputFile.absolutePath)

                    } catch (e: Exception) {
                        result.error("COPY_FAILED", e.message, null)
                    }
                }
            }
    }

    private fun copyStreamToFile(input: InputStream, output: File) {
        val out = FileOutputStream(output)
        val buffer = ByteArray(1024 * 1024)
        var read: Int

        while (true) {
            read = input.read(buffer)
            if (read == -1) break
            out.write(buffer, 0, read)
        }

        out.flush()
        out.close()
        input.close()
    }
}
