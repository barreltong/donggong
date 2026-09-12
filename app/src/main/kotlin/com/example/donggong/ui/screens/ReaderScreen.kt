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
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.VerticalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.SwapHoriz
import androidx.compose.material.icons.rounded.ViewCarousel
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
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
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.example.donggong.core.DonggongBridge
import com.example.donggong.data.Gallery
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
    var showModeMenu by remember { mutableStateOf(false) }

    val scope = rememberCoroutineScope()

    LaunchedEffect(galleryId) {
        isLoading = true
        val loaded = DonggongBridge.getReaderData(galleryId)
        gallery = loaded
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
            .clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null
            ) {
                showControls = !showControls
            }
    ) {
        if (isLoading) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = Color.White)
            }
        } else if (images.isEmpty()) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                Text("이미지를 불러올 수 없습니다.", color = Color.White)
            }
        } else {
            when (readerMode) {
                "webtoon" -> {
                    LazyColumn(
                        state = listState,
                        modifier = Modifier.fillMaxSize()
                    ) {
                        itemsIndexed(images, key = { index, img -> "$index-${img.hash}" }) { _, img ->
                            AsyncImage(
                                model = img.url,
                                contentDescription = null,
                                contentScale = ContentScale.FillWidth,
                                modifier = Modifier.fillMaxWidth()
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
                        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                            AsyncImage(
                                model = images[page].url,
                                contentDescription = null,
                                contentScale = ContentScale.Fit,
                                modifier = Modifier.fillMaxSize()
                            )
                        }
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
                        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                            AsyncImage(
                                model = images[page].url,
                                contentDescription = null,
                                contentScale = ContentScale.Fit,
                                modifier = Modifier.fillMaxSize()
                            )
                        }
                    }
                }

                "doublePage" -> {
                    // Two pages side by side
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

                        Row(modifier = Modifier.fillMaxSize(), horizontalArrangement = Arrangement.Center) {
                            Box(modifier = Modifier.weight(1f).fillMaxSize(), contentAlignment = Alignment.Center) {
                                leftImg?.let {
                                    AsyncImage(
                                        model = it.url,
                                        contentDescription = null,
                                        contentScale = ContentScale.Fit,
                                        modifier = Modifier.fillMaxSize()
                                    )
                                }
                            }
                            Box(modifier = Modifier.weight(1f).fillMaxSize(), contentAlignment = Alignment.Center) {
                                rightImg?.let {
                                    AsyncImage(
                                        model = it.url,
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

        // Top App Bar Overlay
        AnimatedVisibility(
            visible = showControls,
            enter = fadeIn() + slideInVertically { -it },
            exit = fadeOut() + slideOutVertically { -it },
            modifier = Modifier.align(Alignment.TopCenter)
        ) {
            TopAppBar(
                title = {
                    Text(
                        text = gallery?.title ?: "",
                        maxLines = 1,
                        fontSize = 16.sp,
                        color = Color.White
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Rounded.ArrowBack, contentDescription = "Back", tint = Color.White)
                    }
                },
                actions = {
                    if (readerMode == "doublePage") {
                        IconButton(onClick = {
                            doublePageOrder = if (doublePageOrder == "japanese") "international" else "japanese"
                        }) {
                            Icon(
                                Icons.Rounded.SwapHoriz,
                                contentDescription = "Order: $doublePageOrder",
                                tint = if (doublePageOrder == "japanese") MaterialTheme.colorScheme.primary else Color.White
                            )
                        }
                    }

                    Box {
                        IconButton(onClick = { showModeMenu = true }) {
                            Icon(Icons.Rounded.ViewCarousel, contentDescription = "Mode", tint = Color.White)
                        }
                        DropdownMenu(
                            expanded = showModeMenu,
                            onDismissRequest = { showModeMenu = false }
                        ) {
                            DropdownMenuItem(
                                text = { Text("웹툰 모드") },
                                onClick = { readerMode = "webtoon"; showModeMenu = false }
                            )
                            DropdownMenuItem(
                                text = { Text("세로 페이지") },
                                onClick = { readerMode = "verticalPage"; showModeMenu = false }
                            )
                            DropdownMenuItem(
                                text = { Text("가로 페이지") },
                                onClick = { readerMode = "horizontalPage"; showModeMenu = false }
                            )
                            DropdownMenuItem(
                                text = { Text("두 쪽 보기") },
                                onClick = { readerMode = "doublePage"; showModeMenu = false }
                            )
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.Black.copy(alpha = 0.75f)
                )
            )
        }

        // Bottom Controls Overlay
        AnimatedVisibility(
            visible = showControls && totalPages > 0,
            enter = fadeIn() + slideInVertically { it },
            exit = fadeOut() + slideOutVertically { it },
            modifier = Modifier.align(Alignment.BottomCenter)
        ) {
            Surface(
                color = Color.Black.copy(alpha = 0.75f),
                modifier = Modifier.fillMaxWidth()
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
                ) {
                    Text(
                        text = "${currentPage + 1} / $totalPages",
                        color = Color.White,
                        fontSize = 14.sp
                    )
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
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            }
        }
    }
}
