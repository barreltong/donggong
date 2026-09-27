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
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material.icons.rounded.SwapHoriz
import androidx.compose.material.icons.rounded.Swipe
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.TextButton
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
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.annotation.ExperimentalCoilApi
import coil.imageLoader
import coil.request.CachePolicy
import coil.request.ImageRequest
import com.example.donggong.core.DonggongBridge
import com.example.donggong.data.DbManager
import com.example.donggong.data.Gallery
import com.example.donggong.data.Favorites
import com.example.donggong.ui.components.HitomiImage
import com.example.donggong.ui.components.ZoomableBox
import com.example.donggong.ui.theme.tr
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Semaphore
import kotlinx.coroutines.sync.withPermit

@OptIn(ExperimentalMaterial3Api::class, ExperimentalCoilApi::class)
@Composable
fun ReaderScreen(
    galleryId: Long,
    initialPage: Int = 0,
    initialMode: String = "verticalPage",
    initialDoublePageOrder: String = "japanese",
    initialPageTurnDirection: String = "left",
    favorites: Favorites,
    onFavoriteToggle: (String, String, Gallery?) -> Unit,
    onSearchTag: (String) -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier
) {
    var gallery by remember { mutableStateOf<Gallery?>(null) }
    var isLoading by remember { mutableStateOf(true) }
    var showControls by remember { mutableStateOf(false) }

    var readerMode by remember { mutableStateOf(initialMode) }
    var doublePageOrder by remember { mutableStateOf(initialDoublePageOrder) }
    var currentPage by remember { mutableIntStateOf(initialPage.coerceAtLeast(0)) }
    var pageTurnDirection by remember { mutableStateOf(initialPageTurnDirection) }
    var showPageJump by remember { mutableStateOf(false) }
    var pageInput by remember { mutableStateOf("") }
    var showDetails by remember { mutableStateOf(false) }

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
    val verticalPagerState = rememberPagerState(
        initialPage = 0,
        pageCount = { maxOf(1, totalPages) }
    )
    val horizontalPagerState = rememberPagerState(
        initialPage = 0,
        pageCount = { maxOf(1, totalPages) }
    )
    val doublePagerState = rememberPagerState(
        initialPage = 0,
        pageCount = { maxOf(1, (totalPages + 1) / 2) }
    )
    val horizontalReverse = pageTurnDirection == "right"

    val listState = rememberLazyListState()
    val context = LocalContext.current
    val imageLoader = context.imageLoader
    val prefetchJobs = remember(galleryId) { mutableMapOf<String, Job>() }
    val prefetchSlots = remember(galleryId) { Semaphore(2) }
    DisposableEffect(galleryId) {
        onDispose {
            prefetchJobs.values.forEach(Job::cancel)
            prefetchJobs.clear()
        }
    }

    LaunchedEffect(images, currentPage, readerMode) {
        if (images.isEmpty()) return@LaunchedEffect
        val spread = readerMode == "doublePage"
        val first = if (spread) (currentPage / 2 + 1) * 2 else currentPage + 1
        val count = if (spread) 4 else 2
        val upcoming = (first until first + count).mapNotNull(images::getOrNull)
            .map { it.url }.filter(String::isNotBlank).toSet()
        val visible = if (spread) (currentPage / 2 * 2 until currentPage / 2 * 2 + 2)
            .mapNotNull(images::getOrNull).map { it.url }.toSet()
        else setOf(images[currentPage.coerceIn(0, images.lastIndex)].url)

        prefetchJobs.entries.removeAll { (url, job) ->
            if (job.isCompleted) true
            else if (url !in upcoming && url !in visible) {
                job.cancel()
                true
            } else false
        }
        upcoming.filter { it !in visible && it !in prefetchJobs }.forEach { url ->
            prefetchJobs[url] = scope.launch(Dispatchers.IO) {
                delay(100)
                prefetchSlots.withPermit {
                    val cached = imageLoader.diskCache?.openSnapshot(url)
                    if (cached != null) {
                        cached.close()
                        return@withPermit
                    }
                    imageLoader.execute(
                        ImageRequest.Builder(context)
                            .data(url)
                            .diskCacheKey(url)
                            .memoryCachePolicy(CachePolicy.DISABLED)
                            .diskCachePolicy(CachePolicy.WRITE_ONLY)
                            .size(1, 1)
                            .build()
                    )
                }
            }
        }
    }

    LaunchedEffect(readerMode, totalPages) {
        if (totalPages == 0) return@LaunchedEffect
        val page = currentPage.coerceIn(0, totalPages - 1)
        when (readerMode) {
            "webtoon" -> listState.scrollToItem(page)
            "verticalPage" -> verticalPagerState.scrollToPage(page)
            "horizontalPage" -> horizontalPagerState.scrollToPage(page)
            "doublePage" -> doublePagerState.scrollToPage(page / 2)
        }
    }

    LaunchedEffect(readerMode, totalPages) {
        if (totalPages == 0) return@LaunchedEffect
        val pageFlow = when (readerMode) {
            "webtoon" -> snapshotFlow { listState.firstVisibleItemIndex }
            "verticalPage" -> snapshotFlow { verticalPagerState.currentPage }
            "horizontalPage" -> snapshotFlow { horizontalPagerState.currentPage }
            else -> snapshotFlow { doublePagerState.currentPage * 2 }
        }
        pageFlow.collect { page -> currentPage = page.coerceIn(0, totalPages - 1) }
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
                    tr("이미지를 불러올 수 없습니다.", "Unable to load images."),
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
                                ZoomableBox(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .aspectRatio(ratio),
                                    resetKey = index
                                ) {
                                    HitomiImage(
                                        url = img.url,
                                        imageHash = img.hash,
                                        contentDescription = tr("페이지 ${index + 1}", "Page ${index + 1}"),
                                        contentScale = ContentScale.FillWidth,
                                        modifier = Modifier.fillMaxSize()
                                    )
                                }
                            }
                        }
                    }

                    "verticalPage" -> {
                        VerticalPager(state = verticalPagerState, modifier = Modifier.fillMaxSize()) { page ->
                            val img = images[page]
                            ZoomableBox(modifier = Modifier.fillMaxSize(), resetKey = page) {
                                HitomiImage(
                                    url = img.url,
                                    imageHash = img.hash,
                                    contentDescription = tr("페이지 ${page + 1}", "Page ${page + 1}"),
                                    contentScale = ContentScale.Fit,
                                    modifier = Modifier.fillMaxSize()
                                )
                            }
                        }
                    }

                    "horizontalPage" -> {
                        HorizontalPager(
                            state = horizontalPagerState,
                            reverseLayout = horizontalReverse,
                            modifier = Modifier.fillMaxSize()
                        ) { page ->
                            val img = images[page]
                            ZoomableBox(modifier = Modifier.fillMaxSize(), resetKey = page) {
                                HitomiImage(
                                    url = img.url,
                                    imageHash = img.hash,
                                    contentDescription = tr("페이지 ${page + 1}", "Page ${page + 1}"),
                                    contentScale = ContentScale.Fit,
                                    modifier = Modifier.fillMaxSize()
                                )
                            }
                        }
                    }

                    "doublePage" -> {
                        HorizontalPager(
                            state = doublePagerState,
                            reverseLayout = horizontalReverse,
                            modifier = Modifier.fillMaxSize()
                        ) { pairIndex ->
                            val firstIndex = pairIndex * 2
                            val secondIndex = firstIndex + 1
                            val leftImg = if (doublePageOrder == "japanese") {
                                images.getOrNull(secondIndex)
                            } else {
                                images.getOrNull(firstIndex)
                            }
                            val rightImg = if (doublePageOrder == "japanese") {
                                images.getOrNull(firstIndex)
                            } else {
                                images.getOrNull(secondIndex)
                            }
                            ZoomableBox(modifier = Modifier.fillMaxSize(), resetKey = pairIndex) {
                                Row(
                                    modifier = Modifier.fillMaxSize(),
                                    horizontalArrangement = Arrangement.Center,
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    Box(
                                        modifier = Modifier.weight(1f).fillMaxSize(),
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
                                        modifier = Modifier.weight(1f).fillMaxSize(),
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
                            contentDescription = tr("뒤로", "Back"),
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
                    val isFavorite = favorites.isFavorite("gallery", galleryId.toString())
                    IconButton(onClick = { onFavoriteToggle("gallery", galleryId.toString(), gallery) }) {
                        Icon(
                            if (isFavorite) Icons.Filled.Favorite else Icons.Outlined.FavoriteBorder,
                            contentDescription = tr("즐겨찾기", "Favorite"),
                            tint = if (isFavorite) Color.Red else Color.White
                        )
                    }
                    IconButton(onClick = { showDetails = true }) {
                        Icon(Icons.Outlined.Info, contentDescription = tr("작품 정보", "Gallery details"), tint = Color.White)
                    }
                    if (readerMode != "webtoon") {
                        IconButton(onClick = {
                            pageTurnDirection = if (pageTurnDirection == "left") "right" else "left"
                        }) {
                            Icon(Icons.Rounded.Swipe, contentDescription = tr("페이지 넘김 방향: $pageTurnDirection", "Page turn direction: $pageTurnDirection"), tint = Color.White)
                        }
                    }
                    if (readerMode == "doublePage") {
                        IconButton(onClick = {
                            doublePageOrder = if (doublePageOrder == "japanese") "international" else "japanese"
                        }) {
                            Icon(
                                Icons.Rounded.SwapHoriz,
                                contentDescription = tr("순서: $doublePageOrder", "Order: $doublePageOrder"),
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
                        modifier = Modifier.padding(bottom = 6.dp).clickable {
                            pageInput = (currentPage + 1).toString()
                            showPageJump = true
                        }
                    ) {
                        Text(
                            text = "${currentPage + 1} / $totalPages",
                            style = MaterialTheme.typography.labelMedium,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onPrimaryContainer,
                            modifier = Modifier.padding(horizontal = 12.dp, vertical = 4.dp)
                        )
                    }

                    Slider(
                        value = currentPage.toFloat().coerceIn(0f, maxOf(0f, (totalPages - 1).toFloat())),
                        onValueChange = { target ->
                            val targetIndex = target.toInt().coerceIn(0, totalPages - 1)
                            currentPage = targetIndex
                            scope.launch {
                                when (readerMode) {
                                    "webtoon" -> listState.scrollToItem(targetIndex)
                                    "verticalPage" -> verticalPagerState.animateScrollToPage(targetIndex)
                                    "horizontalPage" -> horizontalPagerState.animateScrollToPage(targetIndex)
                                    "doublePage" -> doublePagerState.animateScrollToPage(targetIndex / 2)
                                }
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
                            "webtoon" to tr("웹툰", "Webtoon"),
                            "verticalPage" to tr("세로", "Vertical"),
                            "horizontalPage" to tr("가로", "Horizontal"),
                            "doublePage" to tr("양면", "Double page")
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
        if (showDetails) {
            androidx.compose.material3.ModalBottomSheet(onDismissRequest = { showDetails = false }) {
                DetailSheetContent(
                    galleryId = galleryId,
                    favorites = favorites,
                    onFavoriteToggle = onFavoriteToggle,
                    onStartReader = { _, page ->
                        showDetails = false
                        currentPage = page.coerceIn(0, maxOf(0, totalPages - 1))
                    },
                    onSearchTag = { tag ->
                        showDetails = false
                        onSearchTag(tag)
                    }
                )
            }
        }
        if (showPageJump) {
            AlertDialog(
                onDismissRequest = { showPageJump = false },
                title = { Text(tr("페이지 이동", "Go to page")) },
                text = {
                    OutlinedTextField(
                        value = pageInput,
                        onValueChange = { pageInput = it.filter(Char::isDigit) },
                        label = { Text(tr("페이지 번호 (1 ~ $totalPages)", "Page number (1-$totalPages)")) },
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number)
                    )
                },
                confirmButton = {
                    Button(onClick = {
                        val page = pageInput.toIntOrNull()
                        if (page != null && page in 1..totalPages) {
                            scope.launch {
                                when (readerMode) {
                                    "webtoon" -> listState.scrollToItem(page - 1)
                                    "verticalPage" -> verticalPagerState.scrollToPage(page - 1)
                                    "horizontalPage" -> horizontalPagerState.scrollToPage(page - 1)
                                    "doublePage" -> doublePagerState.scrollToPage((page - 1) / 2)
                                }
                                currentPage = page - 1
                            }
                            showPageJump = false
                        }
                    }) { Text(tr("이동", "Go")) }
                },
                dismissButton = { TextButton(onClick = { showPageJump = false }) { Text(tr("취소", "Cancel")) } }
            )
        }
    }
}
