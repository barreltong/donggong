package com.example.donggong.ui.screens

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
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
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewmodel.compose.viewModel
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
import com.example.donggong.ui.theme.tr

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    favorites: Favorites,
    onFavoriteToggle: (String, String, Gallery?) -> Unit,
    onStartReader: (Long, Int) -> Unit,
    listingMode: String,
    cardViewMode: String,
    onCardViewModeChange: (String) -> Unit,
    defaultLanguage: String,
    pendingSearch: String? = null,
    onPendingSearchConsumed: () -> Unit = {},
    state: HomeViewModel = viewModel(),
    modifier: Modifier = Modifier
) {
    var query by state.query
    var activeQuery by state.activeQuery
    var currentPage by state.currentPage
    var totalCount by state.totalCount
    var galleries by state.galleries
    var isLoading by state.isLoading
    var isRefreshing by state.isRefreshing
    var recentSearches by state.recentSearches
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
        val request = ++state.requestVersion
        val requestedQuery = activeQuery
        isLoading = true
        try {
            val result = if (requestedQuery.isNotBlank()) {
                DonggongBridge.search(requestedQuery, page, defaultLanguage)
            } else {
                DonggongBridge.getList(page, defaultLanguage)
            }
            if (request != state.requestVersion) return
            totalCount = result.totalCount
            galleries = if (listingMode == "pagination" || refresh) {
                result.galleries
            } else {
                val existingIds = galleries.asSequence().map { it.id }.toHashSet()
                galleries + result.galleries.filter { it.id !in existingIds }
            }
            currentPage = page
        } finally {
            if (request == state.requestVersion) {
                isLoading = false
                isRefreshing = false
            }
        }
    }

    fun submitSearch(newQuery: String) {
        val normalized = TagInfo.normalizeQuery(newQuery)
        query = newQuery
        ++state.requestVersion
        activeQuery = normalized
        scope.launch {
            if (normalized.isNotEmpty()) {
                DbManager.addRecentSearch(normalized)
                recentSearches = DbManager.getRecentSearches()
            }
            loadData(1, refresh = true)
            if (cardViewMode == "grid") gridState.scrollToItem(0)
            else listState.scrollToItem(0)
        }
    }

    LaunchedEffect(defaultLanguage) {
        recentSearches = DbManager.getRecentSearches()
        if (galleries.isEmpty() || state.loadedLanguage != defaultLanguage) {
            state.loadedLanguage = defaultLanguage
            loadData(1, refresh = true)
        }
    }

    LaunchedEffect(pendingSearch) {
        if (pendingSearch != null) {
            submitSearch(pendingSearch)
            onPendingSearchConsumed()
        }
    }

    BackHandler(enabled = isSearchFocused || activeQuery.isNotEmpty()) {
        if (isSearchFocused) {
            focusManager.clearFocus()
        } else {
            submitSearch("")
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
                onSearch = { text ->
                    val normalized = TagInfo.normalizeQuery(text)
                    val id = normalized.toLongOrNull()
                    if (id != null && id > 0) {
                        focusManager.clearFocus()
                        onStartReader(id, 0)
                    } else {
                        submitSearch(normalized)
                    }
                },
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
                                text = tr("작품 목록 불러오는 중...", "Loading galleries..."),
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
                                text = tr("검색 결과가 없습니다", "No results found"),
                                style = MaterialTheme.typography.titleMedium,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                            Spacer(modifier = Modifier.height(6.dp))
                            Text(
                                text = tr("다른 검색어나 언어로 다시 시도해보세요", "Try another search or language"),
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
                cardViewMode == "grid" -> {
                    LazyVerticalGrid(
                        columns = GridCells.Adaptive(minSize = 145.dp),
                        state = gridState,
                        contentPadding = PaddingValues(8.dp),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier.fillMaxSize()
                    ) {
                        items(galleries, key = { it.id }) { g ->
                            GalleryCard(
                                gallery = g,
                                isFavorite = favorites.isFavorite("gallery", g.id.toString()),
                                onFavoriteToggle = { onFavoriteToggle("gallery", g.id.toString(), g) },
                                onClick = {
                                    onStartReader(g.id, 0)
                                },
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
                        contentPadding = PaddingValues(horizontal = 8.dp, vertical = 6.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier.fillMaxSize()
                    ) {
                        items(galleries, key = { it.id }) { g ->
                            GalleryCard(
                                gallery = g,
                                isFavorite = favorites.isFavorite("gallery", g.id.toString()),
                                onFavoriteToggle = { onFavoriteToggle("gallery", g.id.toString(), g) },
                                onClick = {
                                    onStartReader(g.id, 0)
                                },
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

    }
}

    selectedDetailId?.let { detId ->
        ModalBottomSheet(
            onDismissRequest = { selectedDetailId = null },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = false),
            containerColor = MaterialTheme.colorScheme.surfaceContainerLow,
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

class HomeViewModel : ViewModel() {
    val query = mutableStateOf("")
    val activeQuery = mutableStateOf("")
    val currentPage = mutableIntStateOf(1)
    val totalCount = mutableIntStateOf(0)
    val galleries = mutableStateOf<List<Gallery>>(emptyList())
    val isLoading = mutableStateOf(false)
    val isRefreshing = mutableStateOf(false)
    val recentSearches = mutableStateOf<List<String>>(emptyList())
    var loadedLanguage: String? = null

    fun clear() {
        ++requestVersion
        query.value = ""
        activeQuery.value = ""
        currentPage.intValue = 1
        totalCount.intValue = 0
        galleries.value = emptyList()
        recentSearches.value = emptyList()
        loadedLanguage = null
        isLoading.value = false
        isRefreshing.value = false
    }
    var requestVersion = 0
}
