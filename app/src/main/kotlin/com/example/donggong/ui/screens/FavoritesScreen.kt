package com.example.donggong.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.LabelOff
import androidx.compose.material.icons.rounded.BookmarkBorder
import androidx.compose.material3.BottomSheetDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.PrimaryTabRow
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Tab
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.rememberModalBottomSheetState
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.example.donggong.core.DonggongBridge
import com.example.donggong.data.DbManager
import com.example.donggong.data.Favorites
import com.example.donggong.data.Gallery
import com.example.donggong.data.TagInfo
import com.example.donggong.ui.theme.tr
import com.example.donggong.ui.components.GalleryCard
import com.example.donggong.ui.components.PaginationBar
import com.example.donggong.ui.components.TagChip
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.filter

private const val FAVORITES_PAGE_SIZE = 25
private const val GALLERY_FETCH_CONCURRENCY = 8

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun FavoritesScreen(
    favorites: Favorites,
    onFavoriteToggle: (String, String, Gallery?) -> Unit,
    onStartReader: (Long, Int) -> Unit,
    onSearchTag: (String) -> Unit,
    listingMode: String = "scroll",
    cardViewMode: String = "detailed",
    modifier: Modifier = Modifier
) {
    var selectedTab by remember { mutableIntStateOf(0) }
    var currentPage by remember { mutableIntStateOf(1) }
    var loadedById by remember { mutableStateOf<Map<Long, Gallery>>(emptyMap()) }
    var isLoading by remember { mutableStateOf(false) }
    var selectedDetailId by remember { mutableStateOf<Long?>(null) }
    var loadGeneration by remember { mutableIntStateOf(0) }

    val scope = rememberCoroutineScope()
    val listState = rememberLazyListState()
    val gridState = rememberLazyGridState()
    val allIds = remember(favorites.galleries) { favorites.galleries.toList() }
    val totalPages = maxOf(1, (allIds.size + FAVORITES_PAGE_SIZE - 1) / FAVORITES_PAGE_SIZE)

    if (currentPage > totalPages) currentPage = totalPages

    val pageIds = remember(allIds, currentPage) {
        val start = ((currentPage - 1) * FAVORITES_PAGE_SIZE).coerceAtMost(allIds.size)
        allIds.subList(start, (start + FAVORITES_PAGE_SIZE).coerceAtMost(allIds.size))
    }
    val visibleGalleries = remember(allIds, loadedById, currentPage, listingMode) {
        val ids = if (listingMode == "pagination") {
            val start = ((currentPage - 1) * FAVORITES_PAGE_SIZE).coerceAtMost(allIds.size)
            allIds.subList(start, (start + FAVORITES_PAGE_SIZE).coerceAtMost(allIds.size))
        } else {
            allIds
        }
        ids.mapNotNull { loadedById[it] }
    }

    suspend fun loadIds(ids: List<Long>) {
        if (ids.isEmpty()) return
        val generation = ++loadGeneration
        isLoading = true
        try {
            val cached = DbManager.getCachedGalleries(ids)
            if (generation != loadGeneration) return
            if (cached.isNotEmpty()) {
                loadedById = loadedById + cached.filterValues { !it.isError }
            }

            val missing = ids.filter { it !in cached }
            missing.chunked(GALLERY_FETCH_CONCURRENCY).forEach { chunk ->
                if (generation != loadGeneration) return
                val fetched = coroutineScope {
                    chunk.map { id ->
                        async { runCatching { DonggongBridge.getDetail(id) }.getOrNull() }
                    }.awaitAll()
                }.filterNotNull().filter { it.id != 0L && !it.isError }
                if (generation != loadGeneration) return
                if (fetched.isNotEmpty()) {
                    loadedById = loadedById + fetched.associateBy { it.id }
                    fetched.forEach { gallery ->
                        runCatching { DbManager.cacheGallery(gallery) }
                    }
                }
            }
        } finally {
            if (generation == loadGeneration) isLoading = false
        }
    }

    LaunchedEffect(allIds, listingMode, currentPage) {
        loadedById = loadedById.filterKeys { it in allIds }
        if (listingMode == "pagination") {
            loadIds(pageIds)
        } else {
            loadIds(allIds.take(FAVORITES_PAGE_SIZE))
        }
    }

    LaunchedEffect(listingMode, cardViewMode, allIds.size, loadedById.size) {
        if (listingMode == "pagination") return@LaunchedEffect
        snapshotFlow {
            if (cardViewMode == "grid") {
                val last = gridState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0
                last >= gridState.layoutInfo.totalItemsCount - 6 && gridState.layoutInfo.totalItemsCount > 0
            } else {
                val last = listState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0
                last >= listState.layoutInfo.totalItemsCount - 4 && listState.layoutInfo.totalItemsCount > 0
            }
        }.distinctUntilChanged().filter { it }.collect {
            if (isLoading) return@collect
            val nextIds = allIds.asSequence()
                .filterNot { it in loadedById }
                .take(FAVORITES_PAGE_SIZE)
                .toList()
            if (nextIds.isNotEmpty()) loadIds(nextIds)
        }
    }
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(tr("즐겨찾기", "Favorites"), fontWeight = FontWeight.Bold) },
                windowInsets = androidx.compose.foundation.layout.WindowInsets(0, 0, 0, 0),
                colors = TopAppBarDefaults.topAppBarColors(containerColor = MaterialTheme.colorScheme.surface)
            )
        },
        bottomBar = {
            if (selectedTab == 0 && listingMode == "pagination" && allIds.isNotEmpty()) {
                PaginationBar(
                    currentPage = currentPage,
                    totalCount = allIds.size,
                    pageSize = FAVORITES_PAGE_SIZE,
                    onPageSelected = { page ->
                        currentPage = page
                        scope.launch {
                            if (cardViewMode == "grid") gridState.scrollToItem(0) else listState.scrollToItem(0)
                        }
                    }
                )
            }
        },
        modifier = modifier
    ) { innerPadding ->
        Column(Modifier.fillMaxSize().padding(innerPadding)) {
            PrimaryTabRow(selectedTabIndex = selectedTab, containerColor = MaterialTheme.colorScheme.surface) {
                Tab(selected = selectedTab == 0, onClick = { selectedTab = 0 }, text = { Text(tr("작품 (${favorites.galleries.size})", "Galleries (${favorites.galleries.size})"), fontWeight = if (selectedTab == 0) FontWeight.Bold else FontWeight.Normal) })
                Tab(selected = selectedTab == 1, onClick = { selectedTab = 1 }, text = { Text(tr("태그 (${favorites.allChips.size})", "Tags (${favorites.allChips.size})"), fontWeight = if (selectedTab == 1) FontWeight.Bold else FontWeight.Normal) })
            }

            if (selectedTab == 0) {
                when {
                    isLoading && visibleGalleries.isEmpty() -> LoadingState()
                    allIds.isEmpty() -> EmptyFavoritesState()
                    cardViewMode == "grid" -> {
                        LazyVerticalGrid(
                            columns = GridCells.Adaptive(minSize = 145.dp),
                            state = gridState,
                            contentPadding = PaddingValues(8.dp),
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            verticalArrangement = Arrangement.spacedBy(8.dp),
                            modifier = Modifier.fillMaxSize()
                        ) {
                            items(visibleGalleries, key = { it.id }) { gallery ->
                                FavoriteGalleryCard(gallery, favorites, onFavoriteToggle, onStartReader, onSearchTag, { selectedDetailId = gallery.id }, "grid")
                            }
                            if (isLoading && visibleGalleries.isNotEmpty()) item { CircularProgressIndicator(Modifier.padding(16.dp)) }
                        }
                    }
                    else -> {
                        LazyColumn(
                            state = listState,
                            contentPadding = PaddingValues(horizontal = 8.dp, vertical = 6.dp),
                            verticalArrangement = Arrangement.spacedBy(8.dp),
                            modifier = Modifier.fillMaxSize()
                        ) {
                            items(visibleGalleries, key = { it.id }) { gallery ->
                                FavoriteGalleryCard(gallery, favorites, onFavoriteToggle, onStartReader, onSearchTag, { selectedDetailId = gallery.id }, cardViewMode)
                            }
                            if (isLoading && visibleGalleries.isNotEmpty()) item { Box(Modifier.fillMaxWidth().padding(16.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator() } }
                        }
                    }
                }
            } else {
                if (favorites.allChips.isEmpty()) EmptyTagsState() else {
                    LazyColumn(Modifier.fillMaxSize().padding(horizontal = 10.dp, vertical = 8.dp)) {
                        item {
                            FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.fillMaxWidth()) {
                                favorites.allChips.forEach { chip ->
                                    TagChip(tag = chip, isFavorite = true, onClick = onSearchTag, onLongClick = { tag ->
                                        val parsed = TagInfo.parse(tag)
                                        onFavoriteToggle(parsed.type, parsed.value, null)
                                    })
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    selectedDetailId?.let { galleryId ->
        ModalBottomSheet(
            onDismissRequest = { selectedDetailId = null },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = false),
            containerColor = MaterialTheme.colorScheme.surface,
            dragHandle = { BottomSheetDefaults.DragHandle() },
            shape = RoundedCornerShape(topStart = 20.dp, topEnd = 20.dp)
        ) {
            DetailSheetContent(
                galleryId = galleryId,
                favorites = favorites,
                onFavoriteToggle = onFavoriteToggle,
                onStartReader = { id, page -> selectedDetailId = null; onStartReader(id, page) },
                onSearchTag = { tag -> selectedDetailId = null; onSearchTag(tag) },
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}

@Composable
private fun FavoriteGalleryCard(
    gallery: Gallery,
    favorites: Favorites,
    onFavoriteToggle: (String, String, Gallery?) -> Unit,
    onStartReader: (Long, Int) -> Unit,
    onSearchTag: (String) -> Unit,
    onLongClick: () -> Unit,
    viewMode: String
) {
    GalleryCard(
        gallery = gallery,
        isFavorite = true,
        onFavoriteToggle = { onFavoriteToggle("gallery", gallery.id.toString(), gallery) },
        onClick = { onStartReader(gallery.id, 0) },
        onTagClick = onSearchTag,
        onLongClick = onLongClick,
        favorites = favorites,
        onTagLongClick = { tag ->
            val parsed = TagInfo.parse(tag)
            onFavoriteToggle(parsed.type, parsed.value, null)
        },
        viewMode = viewMode
    )
}

@Composable
private fun LoadingState() {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
}

@Composable
private fun EmptyFavoritesState() {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.padding(32.dp)) {
            Surface(shape = CircleShape, color = MaterialTheme.colorScheme.surfaceContainerHigh, modifier = Modifier.size(72.dp)) {
                Box(contentAlignment = Alignment.Center) { Icon(Icons.Rounded.BookmarkBorder, null, tint = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.size(36.dp)) }
            }
            Spacer(Modifier.height(16.dp))
            Text(tr("즐겨찾기한 작품이 없습니다", "No favorite galleries"), style = MaterialTheme.typography.titleMedium)
            Spacer(Modifier.height(6.dp))
            Text(tr("작품 상세 화면에서 하트 아이콘을 눌러 추가해보세요", "Tap the heart icon on a gallery details screen to add one"), color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun EmptyTagsState() {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.padding(32.dp)) {
            Surface(shape = CircleShape, color = MaterialTheme.colorScheme.surfaceContainerHigh, modifier = Modifier.size(72.dp)) {
                Box(contentAlignment = Alignment.Center) { Icon(Icons.AutoMirrored.Rounded.LabelOff, null, tint = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.size(36.dp)) }
            }
            Spacer(Modifier.height(16.dp))
            Text(tr("즐겨찾기한 태그가 없습니다", "No favorite tags"), style = MaterialTheme.typography.titleMedium)
            Spacer(Modifier.height(6.dp))
            Text(tr("태그를 길게 눌러 즐겨찾기에 추가할 수 있습니다", "Long-press a tag to add it to favorites"), color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}
