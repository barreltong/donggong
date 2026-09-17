package com.example.donggong.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.BrokenImage
import androidx.compose.material.icons.outlined.Refresh
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

/** Retries after the one-shot hash re-resolution, then the image is marked failed. */
private const val MAX_IMAGE_RETRIES = 3
private const val RETRY_BASE_DELAY_MS = 1500L

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
    var attempt by remember(url) { mutableIntStateOf(0) }
    var didRefreshFromHash by remember(url) { mutableStateOf(false) }
    // Set when a load fails and a retry is still owed; cleared by the retry effect.
    var pendingRetry by remember(url) { mutableStateOf(false) }
    var givenUp by remember(url) { mutableStateOf(false) }

    val context = LocalContext.current
    // The attempt is part of the request identity: ImageRequest compares by value and
    // AsyncImagePainter skips a request equal to the one it already ran, so without
    // this a retry would never be executed and the image would spin forever.
    val imageRequest = remember(context, currentUrl, attempt) {
        ImageRequest.Builder(context)
            .data(currentUrl)
            .crossfade(true)
            .apply {
                if (attempt > 0) {
                    memoryCachePolicy(CachePolicy.WRITE_ONLY)
                    setParameter("donggong_attempt", attempt, memoryCacheKey = null)
                }
            }
            .build()
    }

    LaunchedEffect(currentUrl, pendingRetry) {
        if (!pendingRetry) return@LaunchedEffect

        // gg.js rotates the subdomain and common key, so a stale URL is the usual
        // failure. Re-resolve once per URL; that repair does not consume a retry.
        if (!didRefreshFromHash && !imageHash.isNullOrBlank()) {
            didRefreshFromHash = true
            val refreshed = DonggongBridge.resolveImageUrl(imageHash, forceRefresh = true)
            if (refreshed.isNotBlank() && refreshed != currentUrl) {
                currentUrl = refreshed
                attempt = 0
                pendingRetry = false
                return@LaunchedEffect
            }
        }

        if (attempt >= MAX_IMAGE_RETRIES) {
            givenUp = true
            pendingRetry = false
            return@LaunchedEffect
        }

        delay(RETRY_BASE_DELAY_MS shl attempt)
        attempt++
        pendingRetry = false
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
            if (state is AsyncImagePainter.State.Error && !givenUp) {
                pendingRetry = true
            }
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
                            .background(MaterialTheme.colorScheme.surfaceContainerHigh)
                            .then(
                                if (givenUp) {
                                    Modifier.clickable(
                                        onClickLabel = "이미지 다시 불러오기"
                                    ) {
                                        givenUp = false
                                        didRefreshFromHash = false
                                        attempt = 0
                                        currentUrl = url
                                        pendingRetry = true
                                    }
                                } else {
                                    Modifier
                                }
                            ),
                        contentAlignment = Alignment.Center
                    ) {
                        if (givenUp) {
                            Icon(
                                imageVector = Icons.Outlined.Refresh,
                                contentDescription = "이미지를 불러오지 못했습니다. 눌러서 다시 시도",
                                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.size(24.dp)
                            )
                        } else {
                            CircularProgressIndicator(
                                modifier = Modifier.size(18.dp),
                                strokeWidth = 2.dp,
                                color = MaterialTheme.colorScheme.primary.copy(alpha = 0.5f)
                            )
                        }
                    }
                }
            }
            else -> {
                SubcomposeAsyncImageContent()
            }
        }
    }
}
