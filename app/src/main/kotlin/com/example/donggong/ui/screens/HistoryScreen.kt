package com.example.donggong.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
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
import androidx.compose.material.icons.rounded.DeleteOutline
import androidx.compose.material.icons.rounded.DeleteSweep
import androidx.compose.material.icons.rounded.History
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.BottomSheetDefaults
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.LifecycleResumeEffect
import com.example.donggong.core.DonggongBridge
import com.example.donggong.data.DbManager
import com.example.donggong.data.Favorites
import com.example.donggong.data.Gallery
import com.example.donggong.data.TagInfo
import com.example.donggong.ui.theme.tr
import com.example.donggong.ui.components.GalleryCard
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch

private const val HISTORY_FETCH_CONCURRENCY = 8

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HistoryScreen(
    favorites: Favorites,
    onFavoriteToggle: (String, String, Gallery?) -> Unit,
    onStartReader: (Long, Int) -> Unit,
    onSearchTag: (String) -> Unit,
    cardViewMode: String = "detailed",
    modifier: Modifier = Modifier
) {
    var historyGalleries by remember { mutableStateOf<List<Gallery>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }
    var selectedDetailId by remember { mutableStateOf<Long?>(null) }
    var showClearConfirmation by remember { mutableStateOf(false) }
    var loadGeneration by remember { mutableStateOf(0) }
    val scope = rememberCoroutineScope()
    val listState = rememberLazyListState()
    val gridState = rememberLazyGridState()

    suspend fun loadHistory() {
        val generation = ++loadGeneration
        isLoading = true
        val ids = DbManager.getRecentViewedIds()
        if (generation != loadGeneration) return
        if (ids.isEmpty()) {
            historyGalleries = emptyList()
            isLoading = false
            return
        }

        val cached = DbManager.getCachedGalleries(ids)
        if (generation != loadGeneration) return
        if (cached.isNotEmpty()) {
            val cachedOrdered = ids.mapNotNull { cached[it] }.filter { !it.isError }
            if (cachedOrdered.isNotEmpty()) historyGalleries = cachedOrdered
        }

        val missing = ids.filter { it !in cached }
        val loadedById = cached.toMutableMap()
        missing.chunked(HISTORY_FETCH_CONCURRENCY).forEach { chunk ->
            if (generation != loadGeneration) return
            val fetched = coroutineScope {
                chunk.map { id -> async { runCatching { DonggongBridge.getDetail(id) }.getOrNull() } }.awaitAll()
            }.filterNotNull().filter { it.id != 0L && !it.isError }
            if (generation != loadGeneration) return
            if (fetched.isNotEmpty()) {
                fetched.forEach { gallery ->
                    loadedById[gallery.id] = gallery
                    runCatching { DbManager.cacheGallery(gallery) }
                }
                historyGalleries = ids.mapNotNull { id -> loadedById[id] }.filter { !it.isError }
            }
        }
        if (generation == loadGeneration) isLoading = false
    }

    LifecycleResumeEffect(Unit) {
        scope.launch { loadHistory() }
        onPauseOrDispose { }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(tr("기록", "History"), fontWeight = FontWeight.Bold) },
                actions = {
                    if (historyGalleries.isNotEmpty()) {
                        IconButton(onClick = { showClearConfirmation = true }) {
                            Icon(Icons.Rounded.DeleteSweep, contentDescription = tr("기록 삭제", "Clear history"))
                        }
                    }
                },
                windowInsets = WindowInsets(0, 0, 0, 0),
                colors = TopAppBarDefaults.topAppBarColors(containerColor = MaterialTheme.colorScheme.surface)
            )
        },
        modifier = modifier
    ) { innerPadding ->
        when {
            isLoading && historyGalleries.isEmpty() -> {
                Box(Modifier.fillMaxSize().padding(innerPadding), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
            }
            historyGalleries.isEmpty() -> EmptyHistoryState(innerPadding)
            cardViewMode == "grid" -> {
                LazyVerticalGrid(
                    columns = GridCells.Adaptive(minSize = 145.dp),
                    state = gridState,
                    contentPadding = PaddingValues(8.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier.fillMaxSize().padding(innerPadding)
                ) {
                    items(historyGalleries, key = { it.id }) { gallery ->
                        HistoryGalleryCard(gallery, favorites, onFavoriteToggle, onStartReader, onSearchTag, { selectedDetailId = gallery.id }, "grid")
                    }
                }
            }
            else -> {
                LazyColumn(
                    state = listState,
                    modifier = Modifier.fillMaxSize().padding(innerPadding).padding(horizontal = 8.dp, vertical = 6.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    items(historyGalleries, key = { it.id }) { gallery ->
                        val dismissState = rememberSwipeToDismissBoxState(confirmValueChange = { dismissValue ->
                            if (dismissValue == SwipeToDismissBoxValue.EndToStart || dismissValue == SwipeToDismissBoxValue.StartToEnd) {
                                scope.launch { DbManager.removeRecentViewed(gallery.id) }
                                historyGalleries = historyGalleries.filter { it.id != gallery.id }
                                true
                            } else false
                        })
                        SwipeToDismissBox(
                            state = dismissState,
                            backgroundContent = {
                                val alignment = if (dismissState.dismissDirection == SwipeToDismissBoxValue.StartToEnd) Alignment.CenterStart else Alignment.CenterEnd
                                Box(Modifier.fillMaxSize().clip(RoundedCornerShape(16.dp)).background(MaterialTheme.colorScheme.errorContainer).padding(horizontal = 16.dp), contentAlignment = alignment) {
                                    Icon(Icons.Rounded.DeleteOutline, contentDescription = tr("삭제", "Delete"), tint = MaterialTheme.colorScheme.onErrorContainer)
                                }
                            }
                        ) {
                            HistoryGalleryCard(gallery, favorites, onFavoriteToggle, onStartReader, onSearchTag, { selectedDetailId = gallery.id }, cardViewMode)
                        }
                    }
                }
            }
        }
    }

    if (showClearConfirmation) {
        AlertDialog(
            onDismissRequest = { showClearConfirmation = false },
            title = { Text(tr("기록을 모두 삭제할까요?", "Clear all history?"), fontWeight = FontWeight.Bold) },
            text = { Text(tr("최근 본 작품 기록이 모두 삭제됩니다. 이 작업은 되돌릴 수 없습니다.", "All recently viewed gallery history will be deleted. This action cannot be undone.")) },
            confirmButton = {
                Button(onClick = {
                    showClearConfirmation = false
                    scope.launch {
                        DbManager.clearRecentViewed()
                        loadGeneration++
                        historyGalleries = emptyList()
                    }
                }) { Text(tr("삭제", "Delete")) }
            },
            dismissButton = { TextButton(onClick = { showClearConfirmation = false }) { Text(tr("취소", "Cancel")) } },
            shape = RoundedCornerShape(20.dp)
        )
    }

    selectedDetailId?.let { galleryId ->
        ModalBottomSheet(
            onDismissRequest = { selectedDetailId = null },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = false),
            containerColor = MaterialTheme.colorScheme.surfaceContainerLow,
            dragHandle = { BottomSheetDefaults.DragHandle() },
            shape = RoundedCornerShape(topStart = 20.dp, topEnd = 20.dp)
        ) {
            DetailSheetContent(
                galleryId = galleryId,
                favorites = favorites,
                onFavoriteToggle = onFavoriteToggle,
                onStartReader = { id, page -> selectedDetailId = null; onStartReader(id, page) },
                onSearchTag = { tag -> selectedDetailId = null; onSearchTag(tag) }
            )
        }
    }
}

@Composable
private fun HistoryGalleryCard(
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
        isFavorite = favorites.isFavorite("gallery", gallery.id.toString()),
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
private fun EmptyHistoryState(innerPadding: PaddingValues) {
    Box(Modifier.fillMaxSize().padding(innerPadding), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.padding(32.dp)) {
            Surface(shape = CircleShape, color = MaterialTheme.colorScheme.surfaceContainerHigh, modifier = Modifier.size(64.dp)) {
                Box(contentAlignment = Alignment.Center) { Icon(Icons.Rounded.History, null, tint = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.size(32.dp)) }
            }
            Spacer(Modifier.height(14.dp))
            Text(tr("최근 본 작품이 없습니다", "No recently viewed galleries"), style = MaterialTheme.typography.titleSmall)
            Spacer(Modifier.height(4.dp))
            Text(tr("작품을 열람하면 이곳에 최근 기록이 저장됩니다", "Galleries you view will appear here"), color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}
