package com.example.donggong.ui.screens

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.widget.Toast
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.LabelOff
import androidx.compose.material.icons.rounded.BookmarkBorder
import androidx.compose.material.icons.rounded.FileDownload
import androidx.compose.material.icons.rounded.FileUpload
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.PrimaryTabRow
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Tab
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.example.donggong.core.DonggongBridge
import com.example.donggong.data.DbManager
import com.example.donggong.data.DonggongJsonBackup
import com.example.donggong.data.Favorites
import com.example.donggong.data.Gallery
import com.example.donggong.ui.components.GalleryCard
import com.example.donggong.ui.components.PaginationBar
import com.example.donggong.ui.components.TagChip
import kotlinx.coroutines.launch
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun FavoritesScreen(
    favorites: Favorites,
    onFavoriteToggle: (String, String, Gallery?) -> Unit,
    onFavoritesImported: (Favorites) -> Unit,
    onGalleryClick: (Long) -> Unit,
    onSearchTag: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    var selectedTab by remember { mutableIntStateOf(0) }
    var favoriteGalleries by remember { mutableStateOf<List<Gallery>>(emptyList()) }
    var isLoading by remember { mutableStateOf(false) }
    var currentPage by remember { mutableIntStateOf(1) }
    val pageSize = 25

    var showImportDialog by remember { mutableStateOf(false) }
    var importJsonText by remember { mutableStateOf("") }

    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val listState = rememberLazyListState()
    val json = Json { ignoreUnknownKeys = true; prettyPrint = true }

    val allIds = remember(favorites.galleries) { favorites.galleries.toList() }
    val totalPages = maxOf(1, (allIds.size + pageSize - 1) / pageSize)

    LaunchedEffect(totalPages) {
        if (currentPage > totalPages) {
            currentPage = totalPages
        }
    }

    val startIndex = (currentPage - 1) * pageSize
    val endIndex = minOf(startIndex + pageSize, allIds.size)
    val pageIds = if (startIndex < allIds.size) allIds.subList(startIndex, endIndex) else emptyList()

    LaunchedEffect(pageIds) {
        if (pageIds.isEmpty()) {
            favoriteGalleries = emptyList()
            isLoading = false
            return@LaunchedEffect
        }
        isLoading = true
        val cached = DbManager.getCachedGalleries(pageIds)
        val loaded = pageIds.map { id ->
            cached[id] ?: DonggongBridge.getDetail(id)
        }
        favoriteGalleries = loaded.filter { it.id != 0L }
        isLoading = false
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("즐겨찾기", fontWeight = FontWeight.Bold) },
                actions = {
                    IconButton(onClick = { showImportDialog = true }) {
                        Icon(Icons.Rounded.FileUpload, contentDescription = "Import JSON")
                    }
                    IconButton(onClick = {
                        val backup = DonggongJsonBackup(
                            favoriteId = favorites.galleries.toList(),
                            favoriteArtist = favorites.artists.toList(),
                            favoriteTag = favorites.tags.toList(),
                            favoriteLanguage = favorites.languages.toList(),
                            favoriteGroup = favorites.groups.toList(),
                            favoriteParody = favorites.parodys.toList(),
                            favoriteCharacter = favorites.characters.toList()
                        )
                        val exported = json.encodeToString(backup)
                        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                        clipboard.setPrimaryClip(ClipData.newPlainText("donggong_favorites", exported))
                        Toast.makeText(context, "즐겨찾기 JSON이 클립보드에 복사되었습니다.", Toast.LENGTH_SHORT).show()
                    }) {
                        Icon(Icons.Rounded.FileDownload, contentDescription = "Export JSON")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface
                )
            )
        },
        bottomBar = {
            if (selectedTab == 0 && allIds.isNotEmpty()) {
                PaginationBar(
                    currentPage = currentPage,
                    totalCount = allIds.size,
                    pageSize = pageSize,
                    onPageSelected = { p ->
                        currentPage = p
                        scope.launch {
                            listState.scrollToItem(0)
                        }
                    }
                )
            }
        },
        modifier = modifier
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            PrimaryTabRow(
                selectedTabIndex = selectedTab,
                containerColor = MaterialTheme.colorScheme.surface
            ) {
                Tab(
                    selected = selectedTab == 0,
                    onClick = { selectedTab = 0 },
                    text = { Text("작품 (${favorites.galleries.size})", fontWeight = if (selectedTab == 0) FontWeight.Bold else FontWeight.Normal) }
                )
                Tab(
                    selected = selectedTab == 1,
                    onClick = { selectedTab = 1 },
                    text = { Text("태그 (${favorites.allChips.size})", fontWeight = if (selectedTab == 1) FontWeight.Bold else FontWeight.Normal) }
                )
            }

            if (selectedTab == 0) {
                if (isLoading && favoriteGalleries.isEmpty()) {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(
                            color = MaterialTheme.colorScheme.primary,
                            trackColor = MaterialTheme.colorScheme.surfaceContainerHigh
                        )
                    }
                } else if (allIds.isEmpty()) {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
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
                                        imageVector = Icons.Rounded.BookmarkBorder,
                                        contentDescription = null,
                                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                        modifier = Modifier.size(36.dp)
                                    )
                                }
                            }
                            Spacer(modifier = Modifier.height(16.dp))
                            Text(
                                text = "즐겨찾기한 작품이 없습니다",
                                style = MaterialTheme.typography.titleMedium,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                            Spacer(modifier = Modifier.height(6.dp))
                            Text(
                                text = "작품 상세 화면에서 하트 아이콘을 눌러 추가해보세요",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                } else {
                    LazyColumn(
                        state = listState,
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(horizontal = 6.dp, vertical = 4.dp),
                        verticalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        items(favoriteGalleries, key = { it.id }) { gallery ->
                            GalleryCard(
                                gallery = gallery,
                                isFavorite = true,
                                onFavoriteToggle = { onFavoriteToggle("gallery", gallery.id.toString(), gallery) },
                                onClick = { onGalleryClick(gallery.id) },
                                onTagClick = onSearchTag,
                                viewMode = "detailed"
                            )
                        }
                    }
                }
            } else {
                if (favorites.allChips.isEmpty()) {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
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
                                        imageVector = Icons.AutoMirrored.Rounded.LabelOff,
                                        contentDescription = null,
                                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                        modifier = Modifier.size(36.dp)
                                    )
                                }
                            }
                            Spacer(modifier = Modifier.height(16.dp))
                            Text(
                                text = "즐겨찾기한 태그가 없습니다",
                                style = MaterialTheme.typography.titleMedium,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                            Spacer(modifier = Modifier.height(6.dp))
                            Text(
                                text = "태그를 길게 눌러 즐겨찾기에 추가할 수 있습니다",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                } else {
                    LazyColumn(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(horizontal = 10.dp, vertical = 8.dp)
                    ) {
                        item {
                            FlowRow(
                                horizontalArrangement = Arrangement.spacedBy(6.dp),
                                verticalArrangement = Arrangement.spacedBy(6.dp),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                favorites.allChips.forEach { chip ->
                                    TagChip(
                                        tag = chip,
                                        onClick = onSearchTag,
                                        onLongClick = { onFavoriteToggle("tag", chip, null) }
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    if (showImportDialog) {
        AlertDialog(
            onDismissRequest = { showImportDialog = false },
            title = { Text("즐겨찾기 가져오기", fontWeight = FontWeight.Bold) },
            text = {
                Column {
                    Text(
                        "Donggong 또는 Pupil 백업 JSON을 붙여넣으세요:",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    OutlinedTextField(
                        value = importJsonText,
                        onValueChange = { importJsonText = it },
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 10.dp),
                        shape = RoundedCornerShape(12.dp),
                        maxLines = 6
                    )
                }
            },
            confirmButton = {
                Button(
                    onClick = {
                        try {
                            val parsed = json.parseToJsonElement(importJsonText).jsonObject
                            val newFavs = if (parsed.containsKey("favoriteId")) {
                                Favorites(
                                    galleries = parsed["favoriteId"]?.jsonArray?.mapNotNull { it.jsonPrimitive.content.toLongOrNull() }?.toSet() ?: emptySet(),
                                    artists = parsed["favoriteArtist"]?.jsonArray?.map { it.jsonPrimitive.content }?.toSet() ?: emptySet(),
                                    tags = parsed["favoriteTag"]?.jsonArray?.map { it.jsonPrimitive.content }?.toSet() ?: emptySet(),
                                    languages = parsed["favoriteLanguage"]?.jsonArray?.map { it.jsonPrimitive.content }?.toSet() ?: emptySet(),
                                    groups = parsed["favoriteGroup"]?.jsonArray?.map { it.jsonPrimitive.content }?.toSet() ?: emptySet(),
                                    parodys = parsed["favoriteParody"]?.jsonArray?.map { it.jsonPrimitive.content }?.toSet() ?: emptySet(),
                                    characters = parsed["favoriteCharacter"]?.jsonArray?.map { it.jsonPrimitive.content }?.toSet() ?: emptySet()
                                )
                            } else {
                                val galleries = parsed["favorites"]?.jsonArray?.mapNotNull { it.jsonPrimitive.content.toLongOrNull() }?.toSet() ?: emptySet()
                                Favorites(galleries = galleries)
                            }
                            scope.launch {
                                DbManager.importFavorites(newFavs)
                                onFavoritesImported(newFavs)
                                showImportDialog = false
                                Toast.makeText(context, "즐겨찾기를 가져왔습니다.", Toast.LENGTH_SHORT).show()
                            }
                        } catch (e: Exception) {
                            Toast.makeText(context, "올바른 JSON 형식이 아닙니다.", Toast.LENGTH_SHORT).show()
                        }
                    },
                    shape = RoundedCornerShape(10.dp)
                ) {
                    Text("가져오기")
                }
            },
            dismissButton = {
                TextButton(onClick = { showImportDialog = false }) {
                    Text("취소")
                }
            },
            shape = RoundedCornerShape(20.dp)
        )
    }
}
