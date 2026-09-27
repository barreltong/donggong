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
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import android.widget.Toast
import androidx.compose.material.icons.rounded.ContentCopy
import androidx.compose.material.icons.rounded.Translate
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString
import com.example.donggong.core.DonggongBridge
import com.example.donggong.data.DbManager
import com.example.donggong.data.Favorites
import com.example.donggong.data.Gallery
import com.example.donggong.data.TagInfo
import com.example.donggong.ui.theme.tr
import com.example.donggong.ui.components.GalleryIdBadge
import com.example.donggong.ui.components.HitomiImage
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
                title = { Text(tr("작품 상세", "Gallery Details"), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Rounded.ArrowBack, contentDescription = tr("뒤로", "Back"))
                    }
                },
                actions = {
                    IconButton(onClick = { onFavoriteToggle("gallery", galleryId.toString(), null) }) {
                        Icon(
                            imageVector = if (isFav) Icons.Filled.Favorite else Icons.Outlined.FavoriteBorder,
                            contentDescription = tr("즐겨찾기", "Favorite"),
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
                tr("작품 정보를 불러올 수 없습니다.", "Unable to load gallery information."),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.error
            )
        }
    } else {
        val g = gallery!!
        val clipboardManager = LocalClipboardManager.current
        val context = LocalContext.current
        val copiedMessage = tr("작품 ID가 복사되었습니다 (${g.id})", "Gallery ID copied (${g.id})")
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
                    Row(modifier = Modifier.padding(8.dp)) {
                        HitomiImage(
                            url = g.thumbnail,
                            contentDescription = g.title,
                            contentScale = ContentScale.Crop,
                            modifier = Modifier
                                .width(96.dp)
                                .height(136.dp)
                                .clip(RoundedCornerShape(12.dp))
                        )

                        Column(
                            modifier = Modifier
                                .weight(1f)
                                .padding(start = 10.dp),
                            verticalArrangement = Arrangement.spacedBy(3.5.dp)
                        ) {
                            Text(
                                text = g.title,
                                style = MaterialTheme.typography.titleSmall,
                                fontWeight = FontWeight.Bold,
                                fontSize = 13.5.sp,
                                lineHeight = 17.5.sp,
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
                                        fontSize = 11.5.sp,
                                        fontWeight = FontWeight.Normal,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                            }
                            Row(
                                horizontalArrangement = Arrangement.spacedBy(4.dp),
                                verticalAlignment = Alignment.CenterVertically,
                                modifier = Modifier.padding(top = 1.dp)
                            ) {
                                GalleryIdBadge(galleryId = g.id)

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
                                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 1.5.dp)
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
                                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 1.5.dp)
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
                                            modifier = Modifier.padding(horizontal = 6.dp, vertical = 1.5.dp)
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Metadata Info Card (ID tap to copy & Language)
            item {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Surface(
                        shape = RoundedCornerShape(12.dp),
                        color = MaterialTheme.colorScheme.surfaceContainer,
                        border = BorderStroke(0.5.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.35f)),
                        modifier = Modifier
                            .weight(1f)
                            .clickable {
                                clipboardManager.setText(AnnotatedString(g.id.toString()))
                                Toast.makeText(context, copiedMessage, Toast.LENGTH_SHORT).show()
                            }
                    ) {
                        Row(
                            modifier = Modifier.padding(vertical = 8.dp, horizontal = 10.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Surface(
                                shape = CircleShape,
                                color = MaterialTheme.colorScheme.surfaceContainerHigh,
                                modifier = Modifier.size(32.dp)
                            ) {
                                Box(contentAlignment = Alignment.Center) {
                                    Icon(
                                        imageVector = Icons.Rounded.ContentCopy,
                                        contentDescription = null,
                                        tint = MaterialTheme.colorScheme.primary,
                                        modifier = Modifier.size(16.dp)
                                    )
                                }
                            }
                            Spacer(modifier = Modifier.width(8.dp))
                            Column {
                                Text(
                                    text = tr("작품 ID (탭하여 복사)", "Gallery ID (tap to copy)"),
                                    fontSize = 10.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                                Text(
                                    text = "#${g.id}",
                                    fontSize = 12.5.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = MaterialTheme.colorScheme.onSurface
                                )
                            }
                        }
                    }

                    if (!g.language.isNullOrBlank()) {
                        Surface(
                            shape = RoundedCornerShape(12.dp),
                            color = MaterialTheme.colorScheme.surfaceContainer,
                            border = BorderStroke(0.5.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.35f)),
                            modifier = Modifier.weight(1f)
                        ) {
                            Row(
                                modifier = Modifier.padding(vertical = 8.dp, horizontal = 10.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Surface(
                                    shape = CircleShape,
                                    color = MaterialTheme.colorScheme.surfaceContainerHigh,
                                    modifier = Modifier.size(32.dp)
                                ) {
                                    Box(contentAlignment = Alignment.Center) {
                                        Icon(
                                            imageVector = Icons.Rounded.Translate,
                                            contentDescription = null,
                                            tint = MaterialTheme.colorScheme.primary,
                                            modifier = Modifier.size(16.dp)
                                        )
                                    }
                                }
                                Spacer(modifier = Modifier.width(8.dp))
                                Column {
                                    Text(
                                        text = tr("언어", "Language"),
                                        fontSize = 10.sp,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                    Text(
                                        text = g.language.uppercase(),
                                        fontSize = 12.5.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = MaterialTheme.colorScheme.onSurface
                                    )
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
                        onClick = {
                            scope.launch {
                                DbManager.addRecentViewed(g.id)
                                DbManager.cacheGallery(g)
                            }
                            onStartReader(g.id, 0)
                        },
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
                        Text(tr("열람 시작", "Start reading"), fontSize = 12.5.sp, fontWeight = FontWeight.Bold)
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
                        Text(tr("즐겨찾기 완료", "Added to favorites").takeIf { isFav } ?: tr("즐겨찾기", "Add to favorites"), fontSize = 12.5.sp)
                    }
                }
            }

            // Artists Section
            if (g.artists.isNotEmpty()) {
                item {
                    DetailTagGroup(
                        title = tr("작가", "Artists"),
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
                        title = tr("그룹 / 서클", "Groups / Circles"),
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
                        title = tr("시리즈 / 원작", "Series / Original Work"),
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
                        title = tr("캐릭터", "Characters"),
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
                        title = tr("태그 목록", "Tags"),
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
                        text = tr("전체 페이지 미리보기 (${g.images.size}p)", "All page previews (${g.images.size}p)"),
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
                                        .clickable {
                                            scope.launch {
                                                DbManager.addRecentViewed(g.id)
                                                DbManager.cacheGallery(g)
                                            }
                                            onStartReader(g.id, index)
                                        }
                                ) {
                                    HitomiImage(
                                        url = img.url,
                                        imageHash = img.hash,
                                        contentDescription = tr("페이지 ${index + 1}", "Page ${index + 1}"),
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

