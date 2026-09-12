package com.example.donggong.core

import android.net.Uri
import coil.ImageLoader
import coil.annotation.ExperimentalCoilApi
import coil.decode.DataSource
import coil.decode.ImageSource
import coil.fetch.FetchResult
import coil.fetch.Fetcher
import coil.fetch.SourceResult
import coil.request.Options
import okio.Buffer

@OptIn(ExperimentalCoilApi::class)
class HitomiImageFetcher(
    private val url: String,
    private val options: Options,
    private val imageLoader: ImageLoader
) : Fetcher {

    override suspend fun fetch(): FetchResult? {
        val diskCacheKey = options.diskCacheKey ?: url
        val diskCache = imageLoader.diskCache

        if (diskCache != null) {
            val snapshot = diskCache.openSnapshot(diskCacheKey)
            if (snapshot != null) {
                return SourceResult(
                    source = ImageSource(file = snapshot.data, diskCacheKey = diskCacheKey, closeable = snapshot),
                    mimeType = if (url.endsWith(".webp", ignoreCase = true)) "image/webp" else null,
                    dataSource = DataSource.DISK
                )
            }
        }

        val bytes = DonggongBridge.fetchBytes(url)
        if (bytes.isEmpty()) return null

        if (diskCache != null) {
            val editor = diskCache.openEditor(diskCacheKey)
            if (editor != null) {
                try {
                    diskCache.fileSystem.write(editor.data) {
                        write(bytes)
                    }
                    val snapshot = editor.commitAndOpenSnapshot()
                    if (snapshot != null) {
                        return SourceResult(
                            source = ImageSource(file = snapshot.data, diskCacheKey = diskCacheKey, closeable = snapshot),
                            mimeType = if (url.endsWith(".webp", ignoreCase = true)) "image/webp" else null,
                            dataSource = DataSource.NETWORK
                        )
                    }
                } catch (_: Exception) {
                    editor.abort()
                }
            }
        }

        val buffer = Buffer().apply { write(bytes) }
        return SourceResult(
            source = ImageSource(buffer, options.context),
            mimeType = if (url.endsWith(".webp", ignoreCase = true)) "image/webp" else null,
            dataSource = DataSource.NETWORK
        )
    }

    class UriFactory : Fetcher.Factory<Uri> {
        override fun create(data: Uri, options: Options, imageLoader: ImageLoader): Fetcher? {
            val scheme = data.scheme
            if (scheme.equals("https", ignoreCase = true) || scheme.equals("http", ignoreCase = true)) {
                return HitomiImageFetcher(data.toString(), options, imageLoader)
            }
            return null
        }
    }

    class StringFactory : Fetcher.Factory<String> {
        override fun create(data: String, options: Options, imageLoader: ImageLoader): Fetcher? {
            if (data.startsWith("https://", ignoreCase = true) || data.startsWith("http://", ignoreCase = true)) {
                return HitomiImageFetcher(data, options, imageLoader)
            }
            return null
        }
    }
}
