package com.example.donggong.core

import coil.ImageLoader
import coil.decode.DataSource
import coil.decode.ImageSource
import coil.fetch.FetchResult
import coil.fetch.Fetcher
import coil.fetch.SourceResult
import coil.request.Options
import okio.Buffer

class HitomiImageFetcher(
    private val url: String,
    private val options: Options
) : Fetcher {

    override suspend fun fetch(): FetchResult? {
        val bytes = DonggongBridge.fetchBytes(url)
        if (bytes.isEmpty()) return null

        val buffer = Buffer().apply { write(bytes) }
        return SourceResult(
            source = ImageSource(buffer, options.context),
            mimeType = if (url.endsWith(".webp", ignoreCase = true)) "image/webp" else null,
            dataSource = DataSource.NETWORK
        )
    }

    class Factory : Fetcher.Factory<String> {
        override fun create(data: String, options: Options, imageLoader: ImageLoader): Fetcher? {
            if (data.startsWith("https://") || data.startsWith("http://")) {
                return HitomiImageFetcher(data, options)
            }
            return null
        }
    }
}
