package com.example.donggong.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.DeleteSweep
import androidx.compose.material.icons.rounded.History
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
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
                title = { Text("기록", fontWeight = FontWeight.Bold) },
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
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface
                )
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
                CircularProgressIndicator(
                    color = MaterialTheme.colorScheme.primary,
                    trackColor = MaterialTheme.colorScheme.surfaceContainerHigh
                )
            }
        } else if (historyGalleries.isEmpty()) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding),
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
                                imageVector = Icons.Rounded.History,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.size(36.dp)
                            )
                        }
                    }
                    Spacer(modifier = Modifier.height(16.dp))
                    Text(
                        text = "최근 본 작품이 없습니다",
                        style = MaterialTheme.typography.titleMedium,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Spacer(modifier = Modifier.height(6.dp))
                    Text(
                        text = "작품을 열람하면 이곳에 최근 기록이 저장됩니다",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding)
                    .padding(horizontal = 6.dp, vertical = 4.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp)
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
