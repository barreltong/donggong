package com.example.donggong.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.BrokenImage
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImagePainter
import coil.compose.SubcomposeAsyncImage
import coil.compose.SubcomposeAsyncImageContent
import coil.request.CachePolicy
import coil.request.ImageRequest
import com.example.donggong.core.DonggongBridge
import kotlinx.coroutines.delay

@Composable
fun HitomiImage(
    url: String,
    contentDescription: String?,
    modifier: Modifier = Modifier,
    imageHash: String? = null,
    contentScale: ContentScale = ContentScale.Crop,
    alignment: Alignment = Alignment.Center,
    showLoadingPlaceholder: Boolean = true,
    showErrorIndicator: Boolean = true
) {
    var currentUrl by remember(url) { mutableStateOf(url) }
    var retryCount by remember(url) { mutableIntStateOf(0) }
    var isRefreshingUrl by remember(url) { mutableStateOf(false) }
    var didRefreshFromHash by remember(url) { mutableStateOf(false) }
    var isError by remember(url, retryCount, currentUrl) { mutableStateOf(false) }

    val context = LocalContext.current
    val imageRequest = remember(context, currentUrl, retryCount) {
        ImageRequest.Builder(context)
            .data(currentUrl)
            .crossfade(true)
            .apply {
                if (retryCount > 0) {
                    memoryCachePolicy(CachePolicy.WRITE_ONLY)
                }
            }
            .build()
    }

    LaunchedEffect(isError, didRefreshFromHash, isRefreshingUrl, currentUrl) {
        if (!isError || isRefreshingUrl) return@LaunchedEffect

        if (!didRefreshFromHash && !imageHash.isNullOrBlank()) {
            isRefreshingUrl = true
            val refreshed = DonggongBridge.resolveImageUrl(imageHash, forceRefresh = true)
            isRefreshingUrl = false
            didRefreshFromHash = true
            if (refreshed.isNotBlank() && refreshed != currentUrl) {
                currentUrl = refreshed
                retryCount = 0
                isError = false
                return@LaunchedEffect
            }
        }

        delay(2000L)
        retryCount++
        isError = false
    }

    if (currentUrl.isEmpty()) {
        Box(
            modifier = modifier.background(MaterialTheme.colorScheme.surfaceContainerHigh),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Outlined.BrokenImage,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
                modifier = Modifier.size(24.dp)
            )
        }
        return
    }

    SubcomposeAsyncImage(
        model = imageRequest,
        contentDescription = contentDescription,
        modifier = modifier,
        contentScale = contentScale,
        alignment = alignment,
        onState = { state ->
            isError = (state is AsyncImagePainter.State.Error)
        }
    ) {
        when (painter.state) {
            is AsyncImagePainter.State.Loading -> {
                if (showLoadingPlaceholder) {
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .background(MaterialTheme.colorScheme.surfaceContainerHigh),
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(20.dp),
                            strokeWidth = 2.dp,
                            color = MaterialTheme.colorScheme.primary.copy(alpha = 0.6f)
                        )
                    }
                }
            }
            is AsyncImagePainter.State.Error -> {
                if (showErrorIndicator) {
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .background(MaterialTheme.colorScheme.surfaceContainerHigh),
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(18.dp),
                            strokeWidth = 2.dp,
                            color = MaterialTheme.colorScheme.primary.copy(alpha = 0.5f)
                        )
                    }
                }
            }
            else -> {
                SubcomposeAsyncImageContent()
            }
        }
    }
}
