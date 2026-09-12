package com.example.donggong.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.DeleteSweep
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.example.donggong.core.DonggongBridge
import com.example.donggong.data.DbManager
import com.example.donggong.data.Favorites
import com.example.donggong.data.Gallery
import com.example.donggong.ui.components.GalleryCard
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HistoryScreen(
    favorites: Favorites,
    onFavoriteToggle: (String, String, Gallery?) -> Unit,
    onGalleryClick: (Long) -> Unit,
    onSearchTag: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    var historyGalleries by remember { mutableStateOf<List<Gallery>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }
    val scope = rememberCoroutineScope()

    suspend fun loadHistory() {
        isLoading = true
        val ids = DbManager.getRecentViewedIds()
        if (ids.isEmpty()) {
            historyGalleries = emptyList()
            isLoading = false
            return
        }
        val cached = DbManager.getCachedGalleries(ids)
        val loaded = ids.map { id ->
            cached[id] ?: DonggongBridge.getDetail(id)
        }
        historyGalleries = loaded.filter { it.id != 0L }
        isLoading = false
    }

    LaunchedEffect(Unit) {
        loadHistory()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("기록") },
                actions = {
                    if (historyGalleries.isNotEmpty()) {
                        IconButton(onClick = {
                            scope.launch {
                                DbManager.clearRecentViewed()
                                historyGalleries = emptyList()
                            }
                        }) {
                            Icon(Icons.Rounded.DeleteSweep, contentDescription = "Clear History")
                        }
                    }
                }
            )
        },
        modifier = modifier
    ) { innerPadding ->
        if (isLoading) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator()
            }
        } else if (historyGalleries.isEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding),
                contentAlignment = Alignment.Center
            ) {
                Text("최근 본 작품이 없습니다.")
            }
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding)
                    .padding(horizontal = 8.dp, vertical = 4.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                items(historyGalleries, key = { it.id }) { gallery ->
                    GalleryCard(
                        gallery = gallery,
                        isFavorite = favorites.isFavorite("gallery", gallery.id.toString()),
                        onFavoriteToggle = { onFavoriteToggle("gallery", gallery.id.toString(), gallery) },
                        onClick = { onGalleryClick(gallery.id) },
                        onTagClick = onSearchTag,
                        viewMode = "detailed"
                    )
                }
            }
        }
    }
}
