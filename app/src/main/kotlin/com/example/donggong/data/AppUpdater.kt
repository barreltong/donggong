package com.example.donggong.data

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File
import java.io.FileOutputStream

data class OtaRelease(
    val version: String,
    val assetName: String,
    val downloadUrl: String,
    val pageUrl: String,
    val notes: String?
)

object AppUpdater {
    private const val REPO = "barreltong/donggong"
    private val client = OkHttpClient()
    private val json = Json { ignoreUnknownKeys = true }

    suspend fun fetchLatestRelease(): OtaRelease? = withContext(Dispatchers.IO) {
        val request = Request.Builder()
            .url("https://api.github.com/repos/$REPO/releases/latest")
            .header("Accept", "application/vnd.github+json")
            .header("User-Agent", "Donggong-App")
            .build()

        client.newCall(request).execute().use { response ->
            if (!response.isSuccessful) return@withContext null
            val body = response.body?.string() ?: return@withContext null
            val obj = json.parseToJsonElement(body).jsonObject
            val assets = obj["assets"]?.jsonArray ?: return@withContext null

            var apkAsset = assets.firstOrNull {
                val name = it.jsonObject["name"]?.jsonPrimitive?.content ?: ""
                name.endsWith(".apk", ignoreCase = true)
            }?.jsonObject ?: return@withContext null

            val rawVersion = obj["tag_name"]?.jsonPrimitive?.content ?: ""
            val version = normalizeVersion(rawVersion)
            val assetName = apkAsset["name"]?.jsonPrimitive?.content ?: ""
            val downloadUrl = apkAsset["browser_download_url"]?.jsonPrimitive?.content ?: ""
            val pageUrl = obj["html_url"]?.jsonPrimitive?.content ?: ""
            val notes = obj["body"]?.jsonPrimitive?.content

            OtaRelease(
                version = version,
                assetName = assetName,
                downloadUrl = downloadUrl,
                pageUrl = pageUrl,
                notes = notes
            )
        }
    }

    suspend fun downloadRelease(
        context: Context,
        release: OtaRelease,
        onProgress: (Float) -> Unit
    ): File = withContext(Dispatchers.IO) {
        val targetFile = File(context.cacheDir, release.assetName)
        val request = Request.Builder()
            .url(release.downloadUrl)
            .header("User-Agent", "Donggong-App")
            .build()

        client.newCall(request).execute().use { response ->
            if (!response.isSuccessful) throw Exception("HTTP ${response.code}")
            val body = response.body ?: throw Exception("Empty response body")
            val totalBytes = body.contentLength()

            body.byteStream().use { input ->
                FileOutputStream(targetFile).use { output ->
                    val buffer = ByteArray(8192)
                    var read: Int
                    var current = 0L
                    while (input.read(buffer).also { read = it } != -1) {
                        output.write(buffer, 0, read)
                        current += read
                        if (totalBytes > 0) {
                            onProgress(current.toFloat() / totalBytes)
                        }
                    }
                }
            }
        }
        targetFile
    }

    fun canRequestPackageInstalls(context: Context): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
            context.packageManager.canRequestPackageInstalls()
    }

    fun installApk(context: Context, apkFile: File): Boolean {
        if (!apkFile.exists()) return false
        val uri: Uri = FileProvider.getUriForFile(
            context,
            "${context.packageName}.fileprovider",
            apkFile
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(intent)
        return true
    }

    fun isUpdateAvailable(currentVersion: String, latestVersion: String): Boolean {
        return compareVersions(latestVersion, currentVersion) > 0
    }

    private fun normalizeVersion(raw: String): String {
        val withoutPrefix = if (raw.startsWith("v")) raw.substring(1) else raw
        return withoutPrefix.split("+").first().trim()
    }

    private fun compareVersions(a: String, b: String): Int {
        val aParts = parseVersion(a)
        val bParts = parseVersion(b)
        val maxLen = maxOf(aParts.size, bParts.size)
        for (i in 0 until maxLen) {
            val aVal = if (i < aParts.size) aParts[i] else 0
            val bVal = if (i < bParts.size) bParts[i] else 0
            if (aVal != bVal) return aVal.compareTo(bVal)
        }
        return 0
    }

    private fun parseVersion(version: String): List<Int> {
        val cleaned = normalizeVersion(version)
        return cleaned.split(Regex("[.\\-]")).map {
            it.replace(Regex("[^0-9]"), "").toIntOrNull() ?: 0
        }
    }
}
