package com.example.donggong

import android.app.Application
import coil.ImageLoader
import coil.ImageLoaderFactory
import coil.disk.DiskCache
import coil.memory.MemoryCache
import com.example.donggong.core.HitomiImageFetcher
import com.example.donggong.data.DbManager

class DonggongApp : Application(), ImageLoaderFactory {
    override fun onCreate() {
        super.onCreate()
        DbManager.init(this)
    }

    override fun newImageLoader(): ImageLoader {
        return ImageLoader.Builder(this)
            .components {
                add(HitomiImageFetcher.UriFactory())
                add(HitomiImageFetcher.StringFactory())
            }
            .memoryCache {
                MemoryCache.Builder(this)
                    .maxSizePercent(0.25)
                    .build()
            }
            .diskCache {
                DiskCache.Builder()
                    .directory(cacheDir.resolve("image_cache"))
                    .maxSizePercent(0.05)
                    .build()
            }
            .crossfade(true)
            .build()
    }
}
