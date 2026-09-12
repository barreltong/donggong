package com.example.donggong.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.VerticalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.AutoStories
import androidx.compose.material.icons.rounded.FitScreen
import androidx.compose.material.icons.rounded.SwapHoriz
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.donggong.core.DonggongBridge
import com.example.donggong.data.DbManager
import com.example.donggong.data.Gallery
import com.example.donggong.ui.components.HitomiImage
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReaderScreen(
    galleryId: Long,
    initialPage: Int = 0,
    initialMode: String = "verticalPage",
    initialDoublePageOrder: String = "japanese",
    onBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    var gallery by remember { mutableStateOf<Gallery?>(null) }
    var isLoading by remember { mutableStateOf(true) }
    var showControls by remember { mutableStateOf(false) }

    var readerMode by remember { mutableStateOf(initialMode) }
    var doublePageOrder by remember { mutableStateOf(initialDoublePageOrder) }
    var currentPage by remember { mutableIntStateOf(initialPage) }

    val scope = rememberCoroutineScope()

    LaunchedEffect(galleryId) {
        isLoading = true
        val loaded = DonggongBridge.getReaderData(galleryId)
        gallery = loaded
        if (!loaded.isError && loaded.id != 0L) {
            DbManager.addRecentViewed(loaded.id)
            DbManager.cacheGallery(loaded)
        }
        isLoading = false
    }

    val images = gallery?.images ?: emptyList()
    val totalPages = images.size

    val listState = rememberLazyListState(initialFirstVisibleItemIndex = initialPage)

    // Sync currentPage for webtoon
    LaunchedEffect(listState, readerMode) {
        if (readerMode == "webtoon") {
            snapshotFlow { listState.firstVisibleItemIndex }
                .collect { currentPage = it }
        }
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        if (isLoading) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator(
                    color = MaterialTheme.colorScheme.primary,
                    trackColor = Color.DarkGray
                )
            }
        } else if (images.isEmpty()) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    "이미지를 불러올 수 없습니다.",
                    color = Color.White,
                    style = MaterialTheme.typography.bodyLarge
                )
            }
        } else {
            // Main Reader Viewport with tap-to-toggle-controls
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .clickable(
                        interactionSource = remember { MutableInteractionSource() },
                        indication = null
                    ) {
                        showControls = !showControls
                    }
            ) {
                when (readerMode) {
                    "webtoon" -> {
                        LazyColumn(
                            state = listState,
                            modifier = Modifier.fillMaxSize()
                        ) {
                            itemsIndexed(images) { index, img ->
                                val ratio = if (img.width > 0 && img.height > 0) {
                                    img.width.toFloat() / img.height.toFloat()
                                } else 0.70f
                                HitomiImage(
                                    url = img.url,
                                    imageHash = img.hash,
                                    contentDescription = "Page ${index + 1}",
                                    contentScale = ContentScale.FillWidth,
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .aspectRatio(ratio)
                                )
                            }
                        }
                    }

                    "verticalPage" -> {
                        val pagerState = rememberPagerState(
                            initialPage = currentPage.coerceIn(0, maxOf(0, totalPages - 1)),
                            pageCount = { totalPages }
                        )
                        LaunchedEffect(pagerState) {
                            snapshotFlow { pagerState.currentPage }.collect { currentPage = it }
                        }

                        VerticalPager(
                            state = pagerState,
                            modifier = Modifier.fillMaxSize()
                        ) { page ->
                            val img = images[page]
                            HitomiImage(
                                url = img.url,
                                imageHash = img.hash,
                                contentDescription = "Page ${page + 1}",
                                contentScale = ContentScale.Fit,
                                modifier = Modifier.fillMaxSize()
                            )
                        }
                    }

                    "horizontalPage" -> {
                        val pagerState = rememberPagerState(
                            initialPage = currentPage.coerceIn(0, maxOf(0, totalPages - 1)),
                            pageCount = { totalPages }
                        )
                        LaunchedEffect(pagerState) {
                            snapshotFlow { pagerState.currentPage }.collect { currentPage = it }
                        }

                        HorizontalPager(
                            state = pagerState,
                            modifier = Modifier.fillMaxSize()
                        ) { page ->
                            val img = images[page]
                            HitomiImage(
                                url = img.url,
                                imageHash = img.hash,
                                contentDescription = "Page ${page + 1}",
                                contentScale = ContentScale.Fit,
                                modifier = Modifier.fillMaxSize()
                            )
                        }
                    }

                    "doublePage" -> {
                        val doublePageCount = (totalPages + 1) / 2
                        val pagerState = rememberPagerState(
                            initialPage = (currentPage / 2).coerceIn(0, maxOf(0, doublePageCount - 1)),
                            pageCount = { doublePageCount }
                        )
                        LaunchedEffect(pagerState) {
                            snapshotFlow { pagerState.currentPage }.collect { currentPage = it * 2 }
                        }

                        HorizontalPager(
                            state = pagerState,
                            modifier = Modifier.fillMaxSize()
                        ) { pairIndex ->
                            val firstIndex = pairIndex * 2
                            val secondIndex = firstIndex + 1

                            val leftImg = if (doublePageOrder == "japanese") {
                                if (secondIndex < totalPages) images[secondIndex] else null
                            } else {
                                if (firstIndex < totalPages) images[firstIndex] else null
                            }

                            val rightImg = if (doublePageOrder == "japanese") {
                                if (firstIndex < totalPages) images[firstIndex] else null
                            } else {
                                if (secondIndex < totalPages) images[secondIndex] else null
                            }

                            Row(
                                modifier = Modifier.fillMaxSize(),
                                horizontalArrangement = Arrangement.Center,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Box(
                                    modifier = Modifier
                                        .weight(1f)
                                        .fillMaxSize(),
                                    contentAlignment = Alignment.Center
                                ) {
                                    leftImg?.let {
                                        HitomiImage(
                                            url = it.url,
                                            imageHash = it.hash,
                                            contentDescription = null,
                                            contentScale = ContentScale.Fit,
                                            modifier = Modifier.fillMaxSize()
                                        )
                                    }
                                }
                                Box(
                                    modifier = Modifier
                                        .weight(1f)
                                        .fillMaxSize(),
                                    contentAlignment = Alignment.Center
                                ) {
                                    rightImg?.let {
                                        HitomiImage(
                                            url = it.url,
                                            imageHash = it.hash,
                                            contentDescription = null,
                                            contentScale = ContentScale.Fit,
                                            modifier = Modifier.fillMaxSize()
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Floating Top Bar Overlay
        AnimatedVisibility(
            visible = showControls,
            enter = fadeIn() + slideInVertically { -it },
            exit = fadeOut() + slideOutVertically { -it },
            modifier = Modifier
                .align(Alignment.TopCenter)
                .padding(top = 40.dp, start = 14.dp, end = 14.dp)
        ) {
            Surface(
                shape = RoundedCornerShape(20.dp),
                color = Color(0xDD1E1A29),
                shadowElevation = 8.dp,
                modifier = Modifier.fillMaxWidth()
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 6.dp)
                ) {
                    IconButton(onClick = onBack) {
                        Icon(
                            Icons.AutoMirrored.Rounded.ArrowBack,
                            contentDescription = "Back",
                            tint = Color.White
                        )
                    }
                    Text(
                        text = gallery?.title ?: "",
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White,
                        modifier = Modifier
                            .weight(1f)
                            .padding(horizontal = 8.dp)
                    )
                    if (readerMode == "doublePage") {
                        IconButton(onClick = {
                            doublePageOrder = if (doublePageOrder == "japanese") "international" else "japanese"
                        }) {
                            Icon(
                                Icons.Rounded.SwapHoriz,
                                contentDescription = "Order: $doublePageOrder",
                                tint = if (doublePageOrder == "japanese") MaterialTheme.colorScheme.primary else Color.LightGray
                            )
                        }
                    }
                }
            }
        }

        // Floating Bottom Controls Overlay
        AnimatedVisibility(
            visible = showControls && totalPages > 0,
            enter = fadeIn() + slideInVertically { it },
            exit = fadeOut() + slideOutVertically { it },
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 32.dp, start = 14.dp, end = 14.dp)
        ) {
            Surface(
                shape = RoundedCornerShape(24.dp),
                color = Color(0xDD1E1A29),
                shadowElevation = 8.dp,
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp)
                ) {
                    // Page indicator pill
                    Surface(
                        shape = CircleShape,
                        color = MaterialTheme.colorScheme.primaryContainer,
                        modifier = Modifier.padding(bottom = 6.dp)
                    ) {
                        Text(
                            text = "${currentPage + 1} / $totalPages",
                            style = MaterialTheme.typography.labelMedium,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onPrimaryContainer,
                            modifier = Modifier.padding(horizontal = 12.dp, vertical = 4.dp)
                        )
                    }

                    // Interactive Slider
                    Slider(
                        value = currentPage.toFloat().coerceIn(0f, maxOf(0f, (totalPages - 1).toFloat())),
                        onValueChange = { target ->
                            val targetIndex = target.toInt()
                            currentPage = targetIndex
                            if (readerMode == "webtoon") {
                                scope.launch { listState.scrollToItem(targetIndex) }
                            }
                        },
                        valueRange = 0f..maxOf(0f, (totalPages - 1).toFloat()),
                        colors = SliderDefaults.colors(
                            thumbColor = MaterialTheme.colorScheme.primary,
                            activeTrackColor = MaterialTheme.colorScheme.primary,
                            inactiveTrackColor = Color.DarkGray
                        ),
                        modifier = Modifier.fillMaxWidth()
                    )

                    // View Mode Quick Toggle Filter Chips
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.padding(top = 4.dp)
                    ) {
                        listOf(
                            "webtoon" to "웹툰",
                            "verticalPage" to "세로",
                            "horizontalPage" to "가로",
                            "doublePage" to "양면"
                        ).forEach { (modeKey, modeName) ->
                            val selected = readerMode == modeKey
                            FilterChip(
                                selected = selected,
                                onClick = { readerMode = modeKey },
                                label = { Text(modeName, fontSize = 12.sp) },
                                shape = RoundedCornerShape(10.dp),
                                colors = FilterChipDefaults.filterChipColors(
                                    selectedContainerColor = MaterialTheme.colorScheme.primary,
                                    selectedLabelColor = MaterialTheme.colorScheme.onPrimary,
                                    containerColor = Color(0xFF2B2638),
                                    labelColor = Color.LightGray
                                ),
                                border = null
                            )
                        }
                    }
                }
            }
        }
    }
}
