package com.example.donggong.ui.screens

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowForwardIos
import androidx.compose.material.icons.automirrored.rounded.MenuBook
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.DarkMode
import androidx.compose.material.icons.rounded.DeleteForever
import androidx.compose.material.icons.rounded.FileDownload
import androidx.compose.material.icons.rounded.FileUpload
import androidx.compose.material.icons.rounded.Language
import androidx.compose.material.icons.rounded.SwapHoriz
import androidx.compose.material.icons.rounded.SwapVert
import androidx.compose.material.icons.rounded.SystemUpdate
import androidx.compose.material.icons.rounded.ViewAgenda
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.ListItem
import androidx.compose.material3.ListItemDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.donggong.data.AppUpdater
import com.example.donggong.data.DbManager
import com.example.donggong.data.DonggongJsonBackup
import com.example.donggong.data.Favorites
import com.example.donggong.data.OtaRelease
import kotlinx.coroutines.launch
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.io.File

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    themeMode: String,
    onThemeModeChange: (String) -> Unit,
    readerMode: String,
    onReaderModeChange: (String) -> Unit,
    doublePageOrder: String,
    onDoublePageOrderChange: (String) -> Unit,
    listingMode: String,
    onListingModeChange: (String) -> Unit,
    cardViewMode: String,
    onCardViewModeChange: (String) -> Unit,
    defaultLanguage: String,
    onDefaultLanguageChange: (String) -> Unit,
    favorites: Favorites,
    onFavoritesImported: (Favorites) -> Unit,
    onResetData: () -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val json = Json { ignoreUnknownKeys = true; prettyPrint = true }

    var isCheckingUpdate by remember { mutableStateOf(false) }
    var availableRelease by remember { mutableStateOf<OtaRelease?>(null) }
    var downloadProgress by remember { mutableFloatStateOf(0f) }
    var isDownloading by remember { mutableStateOf(false) }
    var downloadedApk by remember { mutableStateOf<File?>(null) }
    var showResetDialog by remember { mutableStateOf(false) }
    var showImportDialog by remember { mutableStateOf(false) }
    var importJsonText by remember { mutableStateOf("") }

    // Dropdown states
    var themeMenuExpanded by remember { mutableStateOf(false) }
    var cardViewMenuExpanded by remember { mutableStateOf(false) }
    var listingMenuExpanded by remember { mutableStateOf(false) }
    var languageMenuExpanded by remember { mutableStateOf(false) }
    var readerMenuExpanded by remember { mutableStateOf(false) }
    var doublePageMenuExpanded by remember { mutableStateOf(false) }

    val currentVersion = "2.3.0"

    fun exportFavoritesJson() {
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
    }

    fun parseAndImportJson(rawJson: String) {
        try {
            val parsed = json.parseToJsonElement(rawJson).jsonObject
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
                Toast.makeText(context, "즐겨찾기 ${newFavs.galleries.size}건을 가져왔습니다.", Toast.LENGTH_SHORT).show()
            }
        } catch (_: Exception) {
            Toast.makeText(context, "올바른 JSON 형식이 아닙니다.", Toast.LENGTH_SHORT).show()
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("설정", fontWeight = FontWeight.Bold) },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = MaterialTheme.colorScheme.surface)
            )
        },
        modifier = modifier
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(horizontal = 10.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            // Section 1: Display & Theme
            SettingsGroupCard(title = "화면 및 테마") {
                Box {
                    SettingsDropdownItem(
                        icon = Icons.Rounded.DarkMode,
                        title = "테마 모드",
                        currentValue = when (themeMode) {
                            "dark" -> "다크 모드"
                            "light" -> "라이트 모드"
                            else -> "시스템 설정"
                        },
                        onClick = { themeMenuExpanded = true }
                    )
                    DropdownMenu(
                        expanded = themeMenuExpanded,
                        onDismissRequest = { themeMenuExpanded = false },
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        DropdownOption("시스템 설정", themeMode == "system") {
                            onThemeModeChange("system")
                            themeMenuExpanded = false
                        }
                        DropdownOption("다크 모드", themeMode == "dark") {
                            onThemeModeChange("dark")
                            themeMenuExpanded = false
                        }
                        DropdownOption("라이트 모드", themeMode == "light") {
                            onThemeModeChange("light")
                            themeMenuExpanded = false
                        }
                    }
                }

                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.2f))

                Box {
                    SettingsDropdownItem(
                        icon = Icons.Rounded.ViewAgenda,
                        title = "카드 표시 모드",
                        currentValue = when (cardViewMode) {
                            "detailed" -> "상세 보기 (태그/작가)"
                            "compact" -> "간단히 보기"
                            else -> "그리드 보기 (격자)"
                        },
                        onClick = { cardViewMenuExpanded = true }
                    )
                    DropdownMenu(
                        expanded = cardViewMenuExpanded,
                        onDismissRequest = { cardViewMenuExpanded = false },
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        DropdownOption("상세 보기 (태그/작가)", cardViewMode == "detailed") {
                            onCardViewModeChange("detailed")
                            cardViewMenuExpanded = false
                        }
                        DropdownOption("간단히 보기", cardViewMode == "compact") {
                            onCardViewModeChange("compact")
                            cardViewMenuExpanded = false
                        }
                        DropdownOption("그리드 보기 (격자)", cardViewMode == "grid") {
                            onCardViewModeChange("grid")
                            cardViewMenuExpanded = false
                        }
                    }
                }
            }

            // Section 2: Navigation & Reader
            SettingsGroupCard(title = "탐색 및 리더 설정") {
                Box {
                    SettingsDropdownItem(
                        icon = Icons.Rounded.SwapVert,
                        title = "목록 스크롤 방식",
                        currentValue = if (listingMode == "pagination") "페이지네이션 (하단 바)" else "무한 스크롤",
                        onClick = { listingMenuExpanded = true }
                    )
                    DropdownMenu(
                        expanded = listingMenuExpanded,
                        onDismissRequest = { listingMenuExpanded = false },
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        DropdownOption("페이지네이션 (하단 바)", listingMode == "pagination") {
                            onListingModeChange("pagination")
                            listingMenuExpanded = false
                        }
                        DropdownOption("무한 스크롤", listingMode != "pagination") {
                            onListingModeChange("scroll")
                            listingMenuExpanded = false
                        }
                    }
                }

                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.2f))

                Box {
                    SettingsDropdownItem(
                        icon = Icons.Rounded.Language,
                        title = "기본 언어 필터",
                        currentValue = when (defaultLanguage) {
                            "korean" -> "한국어 (korean)"
                            "all" -> "모든 언어 (all)"
                            "japanese" -> "일본어 (japanese)"
                            "english" -> "영어 (english)"
                            else -> defaultLanguage
                        },
                        onClick = { languageMenuExpanded = true }
                    )
                    DropdownMenu(
                        expanded = languageMenuExpanded,
                        onDismissRequest = { languageMenuExpanded = false },
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        DropdownOption("한국어 (korean)", defaultLanguage == "korean") {
                            onDefaultLanguageChange("korean")
                            languageMenuExpanded = false
                        }
                        DropdownOption("모든 언어 (all)", defaultLanguage == "all") {
                            onDefaultLanguageChange("all")
                            languageMenuExpanded = false
                        }
                        DropdownOption("일본어 (japanese)", defaultLanguage == "japanese") {
                            onDefaultLanguageChange("japanese")
                            languageMenuExpanded = false
                        }
                        DropdownOption("영어 (english)", defaultLanguage == "english") {
                            onDefaultLanguageChange("english")
                            languageMenuExpanded = false
                        }
                    }
                }

                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.2f))

                Box {
                    SettingsDropdownItem(
                        icon = Icons.AutoMirrored.Rounded.MenuBook,
                        title = "기본 리더 모드",
                        currentValue = when (readerMode) {
                            "webtoon" -> "웹툰 모드 (세로 연속)"
                            "verticalPage" -> "세로 페이지 (스와이프)"
                            "horizontalPage" -> "가로 페이지 (스와이프)"
                            else -> "두 쪽 보기 (태블릿/가로)"
                        },
                        onClick = { readerMenuExpanded = true }
                    )
                    DropdownMenu(
                        expanded = readerMenuExpanded,
                        onDismissRequest = { readerMenuExpanded = false },
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        DropdownOption("웹툰 모드 (세로 연속)", readerMode == "webtoon") {
                            onReaderModeChange("webtoon")
                            readerMenuExpanded = false
                        }
                        DropdownOption("세로 페이지 (스와이프)", readerMode == "verticalPage") {
                            onReaderModeChange("verticalPage")
                            readerMenuExpanded = false
                        }
                        DropdownOption("가로 페이지 (스와이프)", readerMode == "horizontalPage") {
                            onReaderModeChange("horizontalPage")
                            readerMenuExpanded = false
                        }
                        DropdownOption("두 쪽 보기 (태블릿/가로)", readerMode == "doublePage") {
                            onReaderModeChange("doublePage")
                            readerMenuExpanded = false
                        }
                    }
                }

                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.2f))

                Box {
                    SettingsDropdownItem(
                        icon = Icons.Rounded.SwapHoriz,
                        title = "두 쪽 보기 순서",
                        currentValue = if (doublePageOrder == "japanese") "우 → 좌 (일본식 만화)" else "좌 → 우 (한국/서양식)",
                        onClick = { doublePageMenuExpanded = true }
                    )
                    DropdownMenu(
                        expanded = doublePageMenuExpanded,
                        onDismissRequest = { doublePageMenuExpanded = false },
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        DropdownOption("우 → 좌 (일본식 만화)", doublePageOrder == "japanese") {
                            onDoublePageOrderChange("japanese")
                            doublePageMenuExpanded = false
                        }
                        DropdownOption("좌 → 우 (한국/서양식)", doublePageOrder != "japanese") {
                            onDoublePageOrderChange("korean")
                            doublePageMenuExpanded = false
                        }
                    }
                }
            }

            // Section 3: App Update & Info
            SettingsGroupCard(title = "앱 정보 및 업데이트") {
                ListItem(
                    leadingContent = {
                        Surface(
                            shape = CircleShape,
                            color = MaterialTheme.colorScheme.primaryContainer,
                            modifier = Modifier.size(32.dp)
                        ) {
                            Box(contentAlignment = Alignment.Center) {
                                Icon(
                                    Icons.Rounded.SystemUpdate,
                                    contentDescription = null,
                                    tint = MaterialTheme.colorScheme.onPrimaryContainer,
                                    modifier = Modifier.size(16.dp)
                                )
                            }
                        }
                    },
                    headlineContent = { Text("동공 (Donggong)", fontSize = 13.5.sp, fontWeight = FontWeight.SemiBold) },
                    supportingContent = {
                        if (isDownloading) {
                            Column(modifier = Modifier.padding(top = 4.dp)) {
                                LinearProgressIndicator(
                                    progress = { downloadProgress },
                                    modifier = Modifier.fillMaxWidth()
                                )
                                Spacer(modifier = Modifier.height(3.dp))
                                Text("${(downloadProgress * 100).toInt()}% 다운로드 중...", fontSize = 11.5.sp)
                            }
                        } else if (availableRelease != null) {
                            Text("새 버전 v${availableRelease?.version} 사용 가능 (현재: v$currentVersion)", fontSize = 11.5.sp)
                        } else {
                            Text("현재 버전 v$currentVersion", fontSize = 11.5.sp)
                        }
                    },
                    trailingContent = {
                        if (isCheckingUpdate) {
                            CircularProgressIndicator(modifier = Modifier.size(20.dp))
                        } else if (downloadedApk != null) {
                            Button(
                                onClick = { AppUpdater.installApk(context, downloadedApk!!) },
                                shape = RoundedCornerShape(8.dp)
                            ) {
                                Text("설치", fontSize = 12.sp)
                            }
                        } else if (availableRelease != null) {
                            Button(
                                onClick = {
                                    scope.launch {
                                        isDownloading = true
                                        downloadedApk = AppUpdater.downloadRelease(
                                            context = context,
                                            release = availableRelease!!,
                                            onProgress = { downloadProgress = it }
                                        )
                                        isDownloading = false
                                    }
                                },
                                shape = RoundedCornerShape(8.dp)
                            ) {
                                Text("다운로드", fontSize = 12.sp)
                            }
                        } else {
                            FilledTonalButton(
                                onClick = {
                                    scope.launch {
                                        isCheckingUpdate = true
                                        val rel = AppUpdater.fetchLatestRelease()
                                        if (rel != null && AppUpdater.isUpdateAvailable(currentVersion, rel.version)) {
                                            availableRelease = rel
                                        } else {
                                            availableRelease = null
                                            Toast.makeText(context, "최신 버전입니다.", Toast.LENGTH_SHORT).show()
                                        }
                                        isCheckingUpdate = false
                                    }
                                },
                                shape = RoundedCornerShape(8.dp)
                            ) {
                                Text("확인", fontSize = 12.sp)
                            }
                        }
                    },
                    colors = ListItemDefaults.colors(containerColor = Color.Transparent)
                )
            }

            // Section 4: Data Management (Favorites Export / Import / Reset)
            SettingsGroupCard(title = "데이터 및 백업 관리") {
                SettingsActionItem(
                    icon = Icons.Rounded.FileDownload,
                    iconTint = MaterialTheme.colorScheme.primary,
                    iconBg = MaterialTheme.colorScheme.primaryContainer,
                    title = "즐겨찾기 내보내기",
                    subtitle = "즐겨찾기 데이터(${favorites.galleries.size}작품, ${favorites.allChips.size}태그)를 클립보드로 복사합니다",
                    onClick = { exportFavoritesJson() }
                )

                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.2f))

                SettingsActionItem(
                    icon = Icons.Rounded.FileUpload,
                    iconTint = MaterialTheme.colorScheme.tertiary,
                    iconBg = MaterialTheme.colorScheme.tertiaryContainer,
                    title = "즐겨찾기 가져오기",
                    subtitle = "Donggong 또는 Pupil 백업 JSON을 입력하여 복원합니다",
                    onClick = { showImportDialog = true }
                )

                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.2f))

                SettingsActionItem(
                    icon = Icons.Rounded.DeleteForever,
                    iconTint = MaterialTheme.colorScheme.error,
                    iconBg = MaterialTheme.colorScheme.errorContainer,
                    title = "데이터 및 캐시 초기화",
                    subtitle = "즐겨찾기, 최근 본 기록, 검색 기록을 모두 영구 삭제합니다",
                    onClick = { showResetDialog = true }
                )
            }

            Spacer(modifier = Modifier.height(16.dp))
        }

        if (showImportDialog) {
            AlertDialog(
                onDismissRequest = { showImportDialog = false },
                title = { Text("즐겨찾기 가져오기", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold) },
                text = {
                    Column {
                        Text(
                            "백업 JSON을 붙여넣으세요:",
                            fontSize = 12.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        OutlinedTextField(
                            value = importJsonText,
                            onValueChange = { importJsonText = it },
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(top = 8.dp),
                            shape = RoundedCornerShape(10.dp),
                            maxLines = 6
                        )
                    }
                },
                confirmButton = {
                    Button(
                        onClick = { parseAndImportJson(importJsonText) },
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Text("가져오기")
                    }
                },
                dismissButton = {
                    TextButton(onClick = { showImportDialog = false }) {
                        Text("취소")
                    }
                },
                shape = RoundedCornerShape(16.dp)
            )
        }

        if (showResetDialog) {
            AlertDialog(
                onDismissRequest = { showResetDialog = false },
                title = { Text("데이터 초기화", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold) },
                text = { Text("즐겨찾기, 최근 본 기록, 검색 기록이 모두 영구 삭제됩니다. 계속하시겠습니까?", fontSize = 13.sp) },
                confirmButton = {
                    Button(
                        onClick = {
                            scope.launch {
                                DbManager.resetAllData()
                                onResetData()
                                showResetDialog = false
                                Toast.makeText(context, "데이터가 초기화되었습니다.", Toast.LENGTH_SHORT).show()
                            }
                        },
                        colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Text("초기화")
                    }
                },
                dismissButton = {
                    TextButton(onClick = { showResetDialog = false }) {
                        Text("취소")
                    }
                },
                shape = RoundedCornerShape(16.dp)
            )
        }
    }
}

@Composable
private fun DropdownOption(
    title: String,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    DropdownMenuItem(
        text = {
            Text(
                title,
                fontSize = 13.sp,
                fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                color = if (isSelected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface
            )
        },
        trailingIcon = if (isSelected) {
            {
                Icon(
                    Icons.Rounded.Check,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(16.dp)
                )
            }
        } else null,
        onClick = onClick
    )
}

@Composable
private fun SettingsGroupCard(
    title: String,
    content: @Composable () -> Unit
) {
    Column {
        Text(
            text = title,
            fontSize = 12.sp,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.primary,
            modifier = Modifier.padding(start = 6.dp, bottom = 4.dp)
        )
        Card(
            shape = RoundedCornerShape(12.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
            border = BorderStroke(0.8.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.3f)),
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(modifier = Modifier.padding(vertical = 2.dp)) {
                content()
            }
        }
    }
}

@Composable
private fun SettingsDropdownItem(
    icon: ImageVector,
    title: String,
    currentValue: String,
    onClick: () -> Unit,
    iconTint: Color = MaterialTheme.colorScheme.onSurfaceVariant,
    iconBg: Color = MaterialTheme.colorScheme.surfaceContainerHigh
) {
    ListItem(
        leadingContent = {
            Surface(
                shape = CircleShape,
                color = iconBg,
                modifier = Modifier.size(32.dp)
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(
                        imageVector = icon,
                        contentDescription = null,
                        tint = iconTint,
                        modifier = Modifier.size(16.dp)
                    )
                }
            }
        },
        headlineContent = {
            Text(title, fontSize = 13.5.sp, fontWeight = FontWeight.Medium)
        },
        supportingContent = {
            Text(currentValue, fontSize = 11.5.sp, color = MaterialTheme.colorScheme.primary)
        },
        trailingContent = {
            Icon(
                Icons.AutoMirrored.Rounded.ArrowForwardIos,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
                modifier = Modifier.size(12.dp)
            )
        },
        colors = ListItemDefaults.colors(containerColor = Color.Transparent),
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
    )
}

@Composable
private fun SettingsActionItem(
    icon: ImageVector,
    title: String,
    subtitle: String,
    onClick: () -> Unit,
    iconTint: Color = MaterialTheme.colorScheme.onSurfaceVariant,
    iconBg: Color = MaterialTheme.colorScheme.surfaceContainerHigh
) {
    ListItem(
        leadingContent = {
            Surface(
                shape = CircleShape,
                color = iconBg,
                modifier = Modifier.size(32.dp)
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(
                        imageVector = icon,
                        contentDescription = null,
                        tint = iconTint,
                        modifier = Modifier.size(16.dp)
                    )
                }
            }
        },
        headlineContent = {
            Text(title, fontSize = 13.5.sp, fontWeight = FontWeight.Medium)
        },
        supportingContent = {
            Text(subtitle, fontSize = 11.5.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        },
        colors = ListItemDefaults.colors(containerColor = Color.Transparent),
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
    )
}
