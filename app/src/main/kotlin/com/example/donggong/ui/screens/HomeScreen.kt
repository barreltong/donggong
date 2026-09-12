package com.example.donggong.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.List
import androidx.compose.material.icons.rounded.GridView
import androidx.compose.material.icons.rounded.KeyboardArrowUp
import androidx.compose.material.icons.rounded.SearchOff
import androidx.compose.material.icons.rounded.ViewAgenda
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
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
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.unit.dp
import com.example.donggong.core.DonggongBridge
import com.example.donggong.data.DbManager
import com.example.donggong.data.Favorites
import com.example.donggong.data.Gallery
import com.example.donggong.ui.components.DonggongSearchBar
import com.example.donggong.ui.components.GalleryCard
import com.example.donggong.ui.components.PaginationBar
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.launch

import androidx.compose.material3.BottomSheetDefaults
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.rememberModalBottomSheetState
import com.example.donggong.data.TagInfo
import com.example.donggong.ui.screens.DetailSheetContent

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    favorites: Favorites,
    onFavoriteToggle: (String, String, Gallery?) -> Unit,
    onStartReader: (Long, Int) -> Unit,
    onGalleryClick: ((Long) -> Unit)? = null,
    listingMode: String,
    cardViewMode: String,
    onCardViewModeChange: (String) -> Unit,
    defaultLanguage: String,
    modifier: Modifier = Modifier
) {
    var query by remember { mutableStateOf("") }
    var activeQuery by remember { mutableStateOf("") }
    var currentPage by remember { mutableIntStateOf(1) }
    var totalCount by remember { mutableIntStateOf(0) }
    var galleries by remember { mutableStateOf<List<Gallery>>(emptyList()) }
    var isLoading by remember { mutableStateOf(false) }
    var isRefreshing by remember { mutableStateOf(false) }
    var recentSearches by remember { mutableStateOf<List<String>>(emptyList()) }
    var selectedDetailId by remember { mutableStateOf<Long?>(null) }
    var isSearchFocused by remember { mutableStateOf(false) }

    val focusManager = LocalFocusManager.current
    val listState = rememberLazyListState()
    val gridState = rememberLazyGridState()
    val scope = rememberCoroutineScope()

    val showFab by remember {
        derivedStateOf {
            if (cardViewMode == "grid") gridState.firstVisibleItemIndex > 4
            else listState.firstVisibleItemIndex > 4
        }
    }

    suspend fun loadData(page: Int, refresh: Boolean = false) {
        if (isLoading && !refresh) return
        isLoading = true
        if (refresh) {
            currentPage = page
        }

        val result = if (activeQuery.isNotBlank()) {
            DonggongBridge.search(activeQuery, page, defaultLanguage)
        } else {
            DonggongBridge.getList(page, defaultLanguage)
        }

        totalCount = result.totalCount
        if (listingMode == "pagination" || refresh) {
            galleries = result.galleries
        } else {
            val existingIds = galleries.map { it.id }.toSet()
            val newItems = result.galleries.filter { it.id !in existingIds }
            galleries = galleries + newItems
        }
        currentPage = page
        isLoading = false
        isRefreshing = false
    }

    fun submitSearch(newQuery: String) {
        activeQuery = newQuery.trim()
        currentPage = 1
        scope.launch {
            if (activeQuery.isNotEmpty()) {
                DbManager.addRecentSearch(activeQuery)
                recentSearches = DbManager.getRecentSearches()
            }
            loadData(1, refresh = true)
            if (cardViewMode == "grid") gridState.scrollToItem(0)
            else listState.scrollToItem(0)
        }
    }

    LaunchedEffect(Unit) {
        recentSearches = DbManager.getRecentSearches()
        loadData(1, refresh = true)
    }

    LaunchedEffect(query) {
        if (query.trim().isEmpty() && activeQuery.isNotEmpty()) {
            activeQuery = ""
            currentPage = 1
            loadData(1, refresh = true)
            if (cardViewMode == "grid") gridState.scrollToItem(0)
            else listState.scrollToItem(0)
        }
    }

    LaunchedEffect(listState.isScrollInProgress, gridState.isScrollInProgress) {
        if (listState.isScrollInProgress || gridState.isScrollInProgress) {
            focusManager.clearFocus()
        }
    }

    // Infinite scroll listener
    if (listingMode != "pagination") {
        LaunchedEffect(listState, gridState, cardViewMode, galleries.size) {
            val flow = if (cardViewMode == "grid") {
                snapshotFlow {
                    val lastVisible = gridState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0
                    val total = gridState.layoutInfo.totalItemsCount
                    lastVisible >= total - 6 && total > 0
                }
            } else {
                snapshotFlow {
                    val lastVisible = listState.layoutInfo.visibleItemsInfo.lastOrNull()?.index ?: 0
                    val total = listState.layoutInfo.totalItemsCount
                    lastVisible >= total - 4 && total > 0
                }
            }

            flow.distinctUntilChanged()
                .filter { it && !isLoading && galleries.size < totalCount }
                .collect {
                    loadData(currentPage + 1, refresh = false)
                }
        }
    }

    Scaffold(
        topBar = {
            DonggongSearchBar(
                query = query,
                onQueryChange = { query = it },
                onSearch = { submitSearch(it) },
                favorites = favorites,
                recentSearches = recentSearches,
                onRemoveRecentSearch = { rem ->
                    scope.launch {
                        DbManager.removeRecentSearch(rem)
                        recentSearches = DbManager.getRecentSearches()
                    }
                },
                onClearAllRecentSearches = {
                    scope.launch {
                        DbManager.clearRecentSearches()
                        recentSearches = emptyList()
                    }
                },
                onFocusChanged = { isSearchFocused = it },
                trailingAction = {
                    Surface(
                        shape = CircleShape,
                        color = MaterialTheme.colorScheme.surfaceContainer,
                        modifier = Modifier.size(48.dp)
                    ) {
                        IconButton(
                            onClick = {
                                focusManager.clearFocus()
                                val nextMode = when (cardViewMode) {
                                    "detailed" -> "compact"
                                    "compact" -> "grid"
                                    else -> "detailed"
                                }
                                onCardViewModeChange(nextMode)
                            },
                            modifier = Modifier.fillMaxSize()
                        ) {
                            Icon(
                                imageVector = when (cardViewMode) {
                                    "grid" -> Icons.Rounded.GridView
                                    "compact" -> Icons.AutoMirrored.Rounded.List
                                    else -> Icons.Rounded.ViewAgenda
                                },
                                contentDescription = "View Mode",
                                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.size(20.dp)
                            )
                        }
                    }
                }
            )
        },
        floatingActionButton = {
            AnimatedVisibility(
                visible = showFab,
                enter = fadeIn() + scaleIn(),
                exit = fadeOut() + scaleOut()
            ) {
                FloatingActionButton(
                    onClick = {
                        scope.launch {
                            if (cardViewMode == "grid") gridState.animateScrollToItem(0)
                            else listState.animateScrollToItem(0)
                        }
                    },
                    containerColor = MaterialTheme.colorScheme.primaryContainer,
                    contentColor = MaterialTheme.colorScheme.onPrimaryContainer,
                    shape = RoundedCornerShape(16.dp)
                ) {
                    Icon(Icons.Rounded.KeyboardArrowUp, contentDescription = "Scroll to top")
                }
            }
        },
        bottomBar = {
            if (listingMode == "pagination" && totalCount > 0) {
                PaginationBar(
                    currentPage = currentPage,
                    totalCount = totalCount,
                    onPageSelected = { p ->
                        scope.launch {
                            loadData(p, refresh = true)
                            if (cardViewMode == "grid") gridState.scrollToItem(0)
                            else listState.scrollToItem(0)
                        }
                    }
                )
            }
        },
        modifier = modifier
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            PullToRefreshBox(
                isRefreshing = isRefreshing,
                onRefresh = {
                    isRefreshing = true
                    scope.launch {
                        loadData(1, refresh = true)
                    }
                },
                modifier = Modifier.fillMaxSize()
            ) {
            when {
                isLoading && galleries.isEmpty() -> {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            CircularProgressIndicator(
                                color = MaterialTheme.colorScheme.primary,
                                trackColor = MaterialTheme.colorScheme.surfaceContainerHigh
                            )
                            Spacer(modifier = Modifier.height(16.dp))
                            Text(
                                text = "작품 목록 불러오는 중...",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
                !isLoading && galleries.isEmpty() -> {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            modifier = Modifier.padding(32.dp)
                        ) {
                            Surface(
                                shape = CircleShape,
                                color = MaterialTheme.colorScheme.surfaceContainerHigh,
                                modifier = Modifier.size(72.dp)
                            ) {
                                Box(contentAlignment = Alignment.Center) {
                                    Icon(
                                        imageVector = Icons.Rounded.SearchOff,
                                        contentDescription = null,
                                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                        modifier = Modifier.size(36.dp)
                                    )
                                }
                            }
                            Spacer(modifier = Modifier.height(16.dp))
                            Text(
                                text = "검색 결과가 없습니다",
                                style = MaterialTheme.typography.titleMedium,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                            Spacer(modifier = Modifier.height(6.dp))
                            Text(
                                text = "다른 검색어나 언어로 다시 시도해보세요",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
                cardViewMode == "grid" -> {
                    LazyVerticalGrid(
                        columns = GridCells.Adaptive(minSize = 130.dp),
                        state = gridState,
                        contentPadding = PaddingValues(6.dp),
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                        verticalArrangement = Arrangement.spacedBy(6.dp),
                        modifier = Modifier.fillMaxSize()
                    ) {
                        items(galleries, key = { it.id }) { g ->
                            GalleryCard(
                                gallery = g,
                                isFavorite = favorites.isFavorite("gallery", g.id.toString()),
                                onFavoriteToggle = { onFavoriteToggle("gallery", g.id.toString(), g) },
                                onClick = { onStartReader(g.id, 0) },
                                onLongClick = { selectedDetailId = g.id },
                                favorites = favorites,
                                onTagClick = { tag ->
                                    query = tag
                                    submitSearch(tag)
                                },
                                onTagLongClick = { tag ->
                                    val parsed = TagInfo.parse(tag)
                                    onFavoriteToggle(parsed.type, parsed.value, null)
                                },
                                viewMode = "grid"
                            )
                        }
                        if (isLoading && galleries.isNotEmpty()) {
                            item {
                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(12.dp),
                                    contentAlignment = Alignment.Center
                                ) {
                                    CircularProgressIndicator(modifier = Modifier.size(28.dp))
                                }
                            }
                        }
                    }
                }
                else -> {
                    LazyColumn(
                        state = listState,
                        contentPadding = PaddingValues(horizontal = 6.dp, vertical = 4.dp),
                        verticalArrangement = Arrangement.spacedBy(6.dp),
                        modifier = Modifier.fillMaxSize()
                    ) {
                        items(galleries, key = { it.id }) { g ->
                            GalleryCard(
                                gallery = g,
                                isFavorite = favorites.isFavorite("gallery", g.id.toString()),
                                onFavoriteToggle = { onFavoriteToggle("gallery", g.id.toString(), g) },
                                onClick = { onStartReader(g.id, 0) },
                                onLongClick = { selectedDetailId = g.id },
                                favorites = favorites,
                                onTagClick = { tag ->
                                    query = tag
                                    submitSearch(tag)
                                },
                                onTagLongClick = { tag ->
                                    val parsed = TagInfo.parse(tag)
                                    onFavoriteToggle(parsed.type, parsed.value, null)
                                },
                                viewMode = cardViewMode
                            )
                        }
                        if (isLoading && galleries.isNotEmpty()) {
                            item {
                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(16.dp),
                                    contentAlignment = Alignment.Center
                                ) {
                                    CircularProgressIndicator(modifier = Modifier.size(32.dp))
                                }
                            }
                        }
                    }
                }
            }
        }

        if (isSearchFocused) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .pointerInput(Unit) {
                        detectTapGestures(
                            onPress = {
                                focusManager.clearFocus()
                            }
                        )
                    }
            )
        }
    }
}

    selectedDetailId?.let { detId ->
        ModalBottomSheet(
            onDismissRequest = { selectedDetailId = null },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = false),
            containerColor = MaterialTheme.colorScheme.surface,
            dragHandle = { BottomSheetDefaults.DragHandle() },
            shape = RoundedCornerShape(topStart = 20.dp, topEnd = 20.dp)
        ) {
            DetailSheetContent(
                galleryId = detId,
                favorites = favorites,
                onFavoriteToggle = onFavoriteToggle,
                onStartReader = { targetId, page ->
                    selectedDetailId = null
                    onStartReader(targetId, page)
                },
                onSearchTag = { tag ->
                    selectedDetailId = null
                    query = tag
                    submitSearch(tag)
                },
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}
