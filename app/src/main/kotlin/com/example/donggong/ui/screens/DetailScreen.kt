package com.example.donggong.ui.screens

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.automirrored.rounded.MenuBook
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.rounded.Brush
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
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
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.example.donggong.core.DonggongBridge
import com.example.donggong.data.DbManager
import com.example.donggong.data.Favorites
import com.example.donggong.data.Gallery
import com.example.donggong.data.TagInfo
import com.example.donggong.ui.components.TagChip
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DetailScreen(
    galleryId: Long,
    favorites: Favorites,
    onFavoriteToggle: (String, String, Gallery?) -> Unit,
    onBack: () -> Unit,
    onStartReader: (Long, Int) -> Unit,
    onSearchTag: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    val isFav = favorites.isFavorite("gallery", galleryId.toString())
    val heartColor by animateColorAsState(
        targetValue = if (isFav) Color(0xFFE53935) else MaterialTheme.colorScheme.onSurfaceVariant,
        label = "heartColor"
    )

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("작품 상세", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Rounded.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(onClick = { onFavoriteToggle("gallery", galleryId.toString(), null) }) {
                        Icon(
                            imageVector = if (isFav) Icons.Filled.Favorite else Icons.Outlined.FavoriteBorder,
                            contentDescription = "Favorite",
                            tint = heartColor
                        )
                    }
                },
                windowInsets = WindowInsets(0, 0, 0, 0),
                colors = TopAppBarDefaults.topAppBarColors(containerColor = MaterialTheme.colorScheme.surface)
            )
        },
        modifier = modifier
    ) { innerPadding ->
        DetailSheetContent(
            galleryId = galleryId,
            favorites = favorites,
            onFavoriteToggle = onFavoriteToggle,
            onStartReader = onStartReader,
            onSearchTag = onSearchTag,
            modifier = Modifier.padding(innerPadding)
        )
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
fun DetailSheetContent(
    galleryId: Long,
    favorites: Favorites,
    onFavoriteToggle: (String, String, Gallery?) -> Unit,
    onStartReader: (Long, Int) -> Unit,
    onSearchTag: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    var gallery by remember { mutableStateOf<Gallery?>(null) }
    var isLoading by remember { mutableStateOf(true) }

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

    val isFav = favorites.isFavorite("gallery", galleryId.toString())
    val heartColor by animateColorAsState(
        targetValue = if (isFav) Color(0xFFE53935) else MaterialTheme.colorScheme.onSurfaceVariant,
        label = "heartColor"
    )

    if (isLoading) {
        Box(
            modifier = modifier
                .fillMaxWidth()
                .height(300.dp),
            contentAlignment = Alignment.Center
        ) {
            CircularProgressIndicator(
                color = MaterialTheme.colorScheme.primary,
                trackColor = MaterialTheme.colorScheme.surfaceContainerHigh
            )
        }
    } else if (gallery == null || gallery?.isError == true) {
        Box(
            modifier = modifier
                .fillMaxWidth()
                .height(200.dp),
            contentAlignment = Alignment.Center
        ) {
            Text(
                "작품 정보를 불러올 수 없습니다.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.error
            )
        }
    } else {
        val g = gallery!!
        LazyColumn(
            modifier = modifier
                .fillMaxWidth()
                .padding(horizontal = 8.dp)
        ) {
            // Hero Header Card
            item {
                Card(
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
                    border = BorderStroke(0.5.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.35f)),
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp)
                ) {
                    Row(modifier = Modifier.padding(6.dp)) {
                        AsyncImage(
                            model = g.thumbnail,
                            contentDescription = g.title,
                            contentScale = ContentScale.Crop,
                            modifier = Modifier
                                .width(84.dp)
                                .height(118.dp)
                                .clip(RoundedCornerShape(10.dp))
                        )

                        Column(
                            modifier = Modifier
                                .weight(1f)
                                .padding(start = 8.dp),
                            verticalArrangement = Arrangement.spacedBy(3.dp)
                        ) {
                            Text(
                                text = g.title,
                                style = MaterialTheme.typography.titleSmall,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onSurface,
                                maxLines = 3
                            )
                            if (g.artists.isNotEmpty()) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Icon(
                                        imageVector = Icons.Rounded.Brush,
                                        contentDescription = null,
                                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                                        modifier = Modifier.size(12.dp)
                                    )
                                    Spacer(modifier = Modifier.width(3.dp))
                                    Text(
                                        text = g.artists.joinToString(", "),
                                        style = MaterialTheme.typography.bodySmall,
                                        fontWeight = FontWeight.Normal,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                            }
                            Row(
                                horizontalArrangement = Arrangement.spacedBy(4.dp),
                                modifier = Modifier.padding(top = 1.dp)
                            ) {
                                if (g.type.isNotEmpty()) {
                                    Surface(
                                        shape = CircleShape,
                                        color = MaterialTheme.colorScheme.surfaceContainerHigh,
                                        contentColor = MaterialTheme.colorScheme.onSurfaceVariant,
                                        border = BorderStroke(0.5.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.35f))
                                    ) {
                                        Text(
                                            text = g.type,
                                            fontSize = 9.5.sp,
                                            fontWeight = FontWeight.Medium,
                                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 1.dp)
                                        )
                                    }
                                }
                                g.language?.let { lang ->
                                    Surface(
                                        shape = CircleShape,
                                        color = MaterialTheme.colorScheme.surfaceContainerHigh,
                                        contentColor = MaterialTheme.colorScheme.onSurfaceVariant,
                                        border = BorderStroke(0.5.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.35f))
                                    ) {
                                        Text(
                                            text = lang,
                                            fontSize = 9.5.sp,
                                            fontWeight = FontWeight.Medium,
                                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 1.dp)
                                        )
                                    }
                                }
                                if (g.pageCount > 0) {
                                    Surface(
                                        shape = CircleShape,
                                        color = MaterialTheme.colorScheme.surfaceContainerHighest
                                    ) {
                                        Text(
                                            text = "${g.pageCount}p",
                                            fontSize = 9.5.sp,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 1.dp)
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Action Buttons
            item {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Button(
                        onClick = { onStartReader(g.id, 0) },
                        modifier = Modifier
                            .weight(1f)
                            .height(36.dp),
                        shape = CircleShape,
                        colors = ButtonDefaults.buttonColors(
                            containerColor = MaterialTheme.colorScheme.primary,
                            contentColor = MaterialTheme.colorScheme.onPrimary
                        )
                    ) {
                        Icon(
                            Icons.AutoMirrored.Rounded.MenuBook,
                            contentDescription = null,
                            modifier = Modifier.size(15.dp)
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("열람 시작", fontSize = 12.5.sp, fontWeight = FontWeight.Bold)
                    }

                    FilledTonalButton(
                        onClick = { onFavoriteToggle("gallery", g.id.toString(), g) },
                        modifier = Modifier
                            .weight(1f)
                            .height(36.dp),
                        shape = CircleShape,
                        colors = ButtonDefaults.filledTonalButtonColors(
                            containerColor = if (isFav) MaterialTheme.colorScheme.errorContainer else MaterialTheme.colorScheme.surfaceContainerHigh,
                            contentColor = if (isFav) MaterialTheme.colorScheme.onErrorContainer else MaterialTheme.colorScheme.onSurface
                        )
                    ) {
                        Icon(
                            imageVector = if (isFav) Icons.Filled.Favorite else Icons.Outlined.FavoriteBorder,
                            contentDescription = null,
                            tint = heartColor,
                            modifier = Modifier.size(15.dp)
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(if (isFav) "즐겨찾기 완료" else "즐겨찾기", fontSize = 12.5.sp)
                    }
                }
            }

            // Artists Section
            if (g.artists.isNotEmpty()) {
                item {
                    DetailTagGroup(
                        title = "작가",
                        items = g.artists.map { "artist:$it" },
                        favorites = favorites,
                        onSearchTag = onSearchTag,
                        onFavoriteToggle = onFavoriteToggle
                    )
                }
            }

            // Groups Section
            if (g.groups.isNotEmpty()) {
                item {
                    DetailTagGroup(
                        title = "그룹 / 서클",
                        items = g.groups.map { "group:$it" },
                        favorites = favorites,
                        onSearchTag = onSearchTag,
                        onFavoriteToggle = onFavoriteToggle
                    )
                }
            }

            // Series Section
            if (g.parodys.isNotEmpty()) {
                item {
                    DetailTagGroup(
                        title = "시리즈 / 원작",
                        items = g.parodys.map { "series:$it" },
                        favorites = favorites,
                        onSearchTag = onSearchTag,
                        onFavoriteToggle = onFavoriteToggle
                    )
                }
            }

            // Characters Section
            if (g.characters.isNotEmpty()) {
                item {
                    DetailTagGroup(
                        title = "캐릭터",
                        items = g.characters.map { "character:$it" },
                        favorites = favorites,
                        onSearchTag = onSearchTag,
                        onFavoriteToggle = onFavoriteToggle
                    )
                }
            }

            // Tags Section
            if (g.tags.isNotEmpty()) {
                item {
                    DetailTagGroup(
                        title = "태그 목록",
                        items = g.tags,
                        favorites = favorites,
                        onSearchTag = onSearchTag,
                        onFavoriteToggle = onFavoriteToggle
                    )
                }
            }

            // Page Previews Grid
            if (g.images.isNotEmpty()) {
                item {
                    Text(
                        text = "전체 페이지 미리보기 (${g.images.size}p)",
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(top = 8.dp, bottom = 4.dp)
                    )
                }

                item {
                    Box(modifier = Modifier.heightIn(min = 180.dp, max = 380.dp)) {
                        LazyVerticalGrid(
                            columns = GridCells.Adaptive(minSize = 78.dp),
                            horizontalArrangement = Arrangement.spacedBy(4.dp),
                            verticalArrangement = Arrangement.spacedBy(4.dp),
                            modifier = Modifier.fillMaxSize()
                        ) {
                            itemsIndexed(g.images) { index, img ->
                                Box(
                                    modifier = Modifier
                                        .aspectRatio(0.72f)
                                        .clip(RoundedCornerShape(8.dp))
                                        .clickable { onStartReader(g.id, index) }
                                ) {
                                    AsyncImage(
                                        model = img.url,
                                        contentDescription = "Page ${index + 1}",
                                        contentScale = ContentScale.Crop,
                                        modifier = Modifier.fillMaxSize()
                                    )
                                    Surface(
                                        shape = RoundedCornerShape(bottomEnd = 6.dp),
                                        color = Color.Black.copy(alpha = 0.65f),
                                        modifier = Modifier.align(Alignment.TopStart)
                                    ) {
                                        Text(
                                            text = "${index + 1}",
                                            color = Color.White,
                                            fontSize = 9.sp,
                                            fontWeight = FontWeight.Medium,
                                            modifier = Modifier.padding(horizontal = 4.dp, vertical = 1.dp)
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }

            item {
                Spacer(modifier = Modifier.height(16.dp))
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun DetailTagGroup(
    title: String,
    items: List<String>,
    favorites: Favorites,
    onSearchTag: (String) -> Unit,
    onFavoriteToggle: (String, String, Gallery?) -> Unit
) {
    if (items.isEmpty()) return
    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerLow),
        border = BorderStroke(0.5.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.35f)),
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 3.dp)
    ) {
        Column(modifier = Modifier.padding(6.dp)) {
            Text(
                text = title,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(start = 2.dp, bottom = 4.dp)
            )
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(4.dp),
                verticalArrangement = Arrangement.spacedBy(3.dp),
                modifier = Modifier.fillMaxWidth()
            ) {
                items.forEach { chipItem ->
                    val parsed = TagInfo.parse(chipItem)
                    TagChip(
                        tag = chipItem,
                        favorites = favorites,
                        onClick = onSearchTag,
                        onLongClick = { onFavoriteToggle(parsed.type, parsed.value, null) }
                    )
                }
            }
        }
    }
}

