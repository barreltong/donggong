package com.example.donggong.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.List
import androidx.compose.material.icons.rounded.GridView
import androidx.compose.material.icons.rounded.KeyboardArrowUp
import androidx.compose.material.icons.rounded.ViewAgenda
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
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

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    favorites: Favorites,
    onFavoriteToggle: (String, String, Gallery?) -> Unit,
    onGalleryClick: (Long) -> Unit,
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

    val listState = rememberLazyListState()
    val gridState = rememberLazyGridState()
    val scope = rememberCoroutineScope()

    val showFab by remember {
        derivedStateOf {
            if (cardViewMode == "grid") gridState.firstVisibleItemIndex > 5
            else listState.firstVisibleItemIndex > 5
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
            Column(modifier = Modifier.fillMaxWidth()) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 4.dp)
                ) {
                    Box(modifier = Modifier.weight(1f)) {
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
                            }
                        )
                    }
                    IconButton(onClick = {
                        val nextMode = when (cardViewMode) {
                            "detailed" -> "compact"
                            "compact" -> "grid"
                            else -> "detailed"
                        }
                        onCardViewModeChange(nextMode)
                    }) {
                        Icon(
                            imageVector = when (cardViewMode) {
                                "grid" -> Icons.Rounded.GridView
                                "compact" -> Icons.AutoMirrored.Rounded.List
                                else -> Icons.Rounded.ViewAgenda
                            },
                            contentDescription = "View Mode"
                        )
                    }
                }
            }
        },
        floatingActionButton = {
            AnimatedVisibility(visible = showFab) {
                FloatingActionButton(
                    onClick = {
                        scope.launch {
                            if (cardViewMode == "grid") gridState.animateScrollToItem(0)
                            else listState.animateScrollToItem(0)
                        }
                    },
                    containerColor = MaterialTheme.colorScheme.primaryContainer,
                    contentColor = MaterialTheme.colorScheme.onPrimaryContainer
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
                    onPageSelected = { targetPage ->
                        scope.launch {
                            loadData(targetPage, refresh = true)
                            if (cardViewMode == "grid") gridState.scrollToItem(0)
                            else listState.scrollToItem(0)
                        }
                    }
                )
            }
        },
        modifier = modifier
    ) { innerPadding ->
        PullToRefreshBox(
            isRefreshing = isRefreshing,
            onRefresh = {
                isRefreshing = true
                scope.launch { loadData(1, refresh = true) }
            },
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            if (galleries.isEmpty() && isLoading) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }
            } else if (galleries.isEmpty()) {
                Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Text(
                        text = if (activeQuery.isNotEmpty()) "검색 결과가 없습니다" else "작품이 없습니다",
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            } else {
                if (cardViewMode == "grid") {
                    LazyVerticalGrid(
                        columns = GridCells.Fixed(2),
                        state = gridState,
                        contentPadding = PaddingValues(8.dp),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier.fillMaxSize()
                    ) {
                        items(galleries, key = { it.id }) { gallery ->
                            GalleryCard(
                                gallery = gallery,
                                isFavorite = favorites.isFavorite("gallery", gallery.id.toString()),
                                onFavoriteToggle = { onFavoriteToggle("gallery", gallery.id.toString(), gallery) },
                                onClick = { onGalleryClick(gallery.id) },
                                onTagClick = { tag ->
                                    query = tag
                                    submitSearch(tag)
                                },
                                viewMode = "grid"
                            )
                        }
                        if (isLoading && listingMode != "pagination") {
                            item {
                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(16.dp),
                                    contentAlignment = Alignment.Center
                                ) {
                                    CircularProgressIndicator()
                                }
                            }
                        }
                    }
                } else {
                    LazyColumn(
                        state = listState,
                        contentPadding = PaddingValues(horizontal = 8.dp, vertical = 4.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier.fillMaxSize()
                    ) {
                        items(galleries, key = { it.id }) { gallery ->
                            GalleryCard(
                                gallery = gallery,
                                isFavorite = favorites.isFavorite("gallery", gallery.id.toString()),
                                onFavoriteToggle = { onFavoriteToggle("gallery", gallery.id.toString(), gallery) },
                                onClick = { onGalleryClick(gallery.id) },
                                onTagClick = { tag ->
                                    query = tag
                                    submitSearch(tag)
                                },
                                viewMode = cardViewMode
                            )
                        }
                        if (isLoading && listingMode != "pagination") {
                            item {
                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(16.dp),
                                    contentAlignment = Alignment.Center
                                ) {
                                    CircularProgressIndicator()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
