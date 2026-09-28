package com.example.donggong.ui.screens

import android.net.Uri
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
import androidx.compose.material.icons.rounded.DarkMode
import androidx.compose.material.icons.rounded.DeleteForever
import androidx.compose.material.icons.rounded.Download
import androidx.compose.material.icons.rounded.FileUpload
import androidx.compose.material.icons.rounded.Language
import androidx.compose.material.icons.rounded.SettingsApplications
import androidx.compose.material.icons.rounded.SwapHoriz
import androidx.compose.material.icons.rounded.SwapVert
import androidx.compose.material.icons.rounded.SystemUpdate
import androidx.compose.material.icons.rounded.ViewAgenda
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.donggong.data.AppUpdater
import com.example.donggong.data.DbManager
import com.example.donggong.data.Favorites
import com.example.donggong.data.FavoritesBackup
import com.example.donggong.data.OtaRelease
import com.example.donggong.ui.theme.tr
import java.io.ByteArrayOutputStream
import java.io.File
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@Composable
fun SettingsScreen(
    themeMode: String,
    onThemeModeChange: (String) -> Unit,
    appLanguage: String,
    onAppLanguageChange: (String) -> Unit,
    readerMode: String,
    onReaderModeChange: (String) -> Unit,
    doublePageOrder: String,
    onDoublePageOrderChange: (String) -> Unit,
    pageTurnDirection: String,
    onPageTurnDirectionChange: (String) -> Unit,
    listingMode: String,
    onListingModeChange: (String) -> Unit,
    cardViewMode: String,
    onCardViewModeChange: (String) -> Unit,
    defaultLanguage: String,
    onDefaultLanguageChange: (String) -> Unit,
    favorites: Favorites,
    onFavoritesImported: (Favorites) -> Unit,
    onResetData: () -> Unit,
    onClearCache: () -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var showResetDialog by remember { mutableStateOf(false) }
    var exportPayload by remember { mutableStateOf("") }
    var availableRelease by remember { mutableStateOf<OtaRelease?>(null) }
    var downloadedApk by remember { mutableStateOf<File?>(null) }
    var checkingUpdate by remember { mutableStateOf(false) }
    var downloading by remember { mutableStateOf(false) }
    var progress by remember { mutableFloatStateOf(0f) }
    val version = remember(context) { AppUpdater.currentVersion(context) }
    val savedMessage = tr("백업 파일이 저장되었습니다.", "Backup file saved.")
    val exportError = tr("내보내기에 실패했습니다.", "Export failed.")
    val importError = tr("지원하지 않거나 손상된 백업 파일입니다.", "Unsupported or corrupted backup file.")
    val importSuccess = tr("즐겨찾기를 가져왔습니다.", "Favorites imported.")
    val cacheSuccess = tr("캐시가 삭제되었습니다.", "Cache cleared.")
    val resetSuccess = tr("데이터가 초기화되었습니다.", "Data reset complete.")
    val updateError = tr("업데이트를 확인하거나 다운로드할 수 없습니다.", "Could not check or download the update.")
    val upToDate = tr("최신 버전입니다.", "You are on the latest version.")
    val exportLauncher = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/json")) { uri: Uri? ->
        if (uri != null) scope.launch {
            try {
                withContext(Dispatchers.IO) {
                    context.contentResolver.openOutputStream(uri)?.use { output ->
                        output.write(exportPayload.toByteArray(Charsets.UTF_8))
                        output.flush()
                    } ?: error("Cannot open backup destination")
                }
                Toast.makeText(context, savedMessage, Toast.LENGTH_SHORT).show()
            } catch (_: Exception) {
                Toast.makeText(context, exportError, Toast.LENGTH_SHORT).show()
            }
        }
    }
    val importLauncher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri: Uri? ->
        if (uri != null) scope.launch {
            val imported = withContext(Dispatchers.IO) {
                try {
                    context.contentResolver.openInputStream(uri)?.use { input ->
                        val bytes = ByteArrayOutputStream()
                        val buffer = ByteArray(8192)
                        while (true) {
                            val count = input.read(buffer)
                            if (count < 0) break
                            if (bytes.size() + count > 8 * 1024 * 1024) return@withContext null
                            bytes.write(buffer, 0, count)
                        }
                        FavoritesBackup.decode(bytes.toString(Charsets.UTF_8.name()))
                    }
                } catch (_: Exception) {
                    null
                }
            }
            if (imported == null) {
                Toast.makeText(context, importError, Toast.LENGTH_SHORT).show()
            } else {
                try {
                    DbManager.importFavorites(imported)
                    onFavoritesImported(imported)
                    Toast.makeText(context, importSuccess, Toast.LENGTH_SHORT).show()
                } catch (_: Exception) {
                    Toast.makeText(context, importError, Toast.LENGTH_SHORT).show()
                }
            }
        }
    }

    Column(
        modifier = modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 12.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(tr("설정", "Settings"), style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold, modifier = Modifier.padding(start = 4.dp, top = 8.dp, bottom = 4.dp))
        SettingsGroupCard(tr("화면 및 테마", "Appearance")) {
            SettingChoice(Icons.Rounded.Language, tr("앱 언어", "App language"), appLanguage, listOf("ko" to "한국어", "en" to "English"), onAppLanguageChange)
            SettingsDivider()
            SettingChoice(Icons.Rounded.DarkMode, tr("테마 모드", "Theme"), themeMode, listOf("system" to tr("시스템 설정", "System"), "dark" to tr("다크 모드", "Dark"), "oled" to tr("OLED 다크", "OLED black"), "light" to tr("라이트 모드", "Light")), onThemeModeChange)
            SettingsDivider()
            SettingChoice(Icons.Rounded.ViewAgenda, tr("카드 표시 모드", "Card layout"), cardViewMode, listOf("detailed" to tr("상세 보기 (태그/작가)", "Detailed (tags and artists)"), "compact" to tr("간단히 보기", "Compact"), "grid" to tr("그리드 보기 (격자)", "Grid")), onCardViewModeChange)
        }
        SettingsGroupCard(tr("탐색 및 리더 설정", "Browsing and reader")) {
            SettingChoice(Icons.Rounded.SwapVert, tr("목록 스크롤 방식", "List navigation"), listingMode, listOf("scroll" to tr("무한 스크롤", "Infinite scroll"), "pagination" to tr("페이지네이션 (하단 바)", "Pagination")), onListingModeChange)
            SettingsDivider()
            SettingChoice(Icons.Rounded.Language, tr("기본 언어 필터", "Default gallery language"), defaultLanguage, listOf("korean" to tr("한국어 (korean)", "Korean"), "all" to tr("모든 언어 (all)", "All languages"), "japanese" to tr("일본어 (japanese)", "Japanese"), "english" to tr("영어 (english)", "English")), onDefaultLanguageChange)
            SettingsDivider()
            SettingChoice(Icons.AutoMirrored.Rounded.MenuBook, tr("기본 리더 모드", "Default reader mode"), readerMode, listOf("webtoon" to tr("웹툰 모드 (세로 연속)", "Webtoon (continuous scroll)"), "verticalPage" to tr("세로 페이지 (스와이프)", "Vertical pages"), "horizontalPage" to tr("가로 페이지 (스와이프)", "Horizontal pages"), "doublePage" to tr("두 쪽 보기 (태블릿/가로)", "Two-page spreads")), onReaderModeChange)
            SettingsDivider()
            SettingChoice(Icons.Rounded.SwapHoriz, tr("두 쪽 보기 순서", "Spread order"), doublePageOrder, listOf("japanese" to tr("우 → 좌 (일본식 만화)", "Right to left"), "international" to tr("좌 → 우 (한국/서양식)", "Left to right")), onDoublePageOrderChange)
            SettingsDivider()
            SettingChoice(Icons.Rounded.SwapHoriz, tr("페이지 넘김 방향", "Page turn direction"), pageTurnDirection, listOf("left" to tr("왼쪽으로 넘김", "Turn left"), "right" to tr("오른쪽으로 넘김", "Turn right")), onPageTurnDirectionChange)
        }
        SettingsGroupCard(tr("앱 정보 및 업데이트", "App info and updates")) {
            Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                SettingsIcon(Icons.Rounded.SystemUpdate, MaterialTheme.colorScheme.primaryContainer, MaterialTheme.colorScheme.onPrimaryContainer)
                Spacer(Modifier.width(12.dp))
                Column(Modifier.weight(1f)) {
                    Text(tr("동공 (Donggong)", "Donggong"), fontSize = 13.5.sp, fontWeight = FontWeight.SemiBold)
                    Text(tr("현재 버전 v$version", "Current version $version"), fontSize = 11.5.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    if (downloading) {
                        LinearProgressIndicator(progress = { progress }, Modifier.fillMaxWidth().padding(top = 5.dp))
                        Text("${(progress * 100).toInt()}%", fontSize = 11.5.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    } else if (availableRelease != null) Text(tr("새 버전 v${availableRelease!!.version} 사용 가능", "Version ${availableRelease!!.version} available"), fontSize = 11.5.sp, color = MaterialTheme.colorScheme.primary)
                }
                Spacer(Modifier.width(8.dp))
                when {
                    checkingUpdate -> CircularProgressIndicator(Modifier.size(24.dp))
                    downloadedApk != null -> Button(onClick = { try { AppUpdater.installApk(context, downloadedApk!!) } catch (_: Exception) { Toast.makeText(context, updateError, Toast.LENGTH_SHORT).show() } }, shape = CircleShape) { Text(tr("설치", "Install"), fontSize = 12.sp) }
                    availableRelease != null -> Button(onClick = {
                        val release = availableRelease ?: return@Button
                        scope.launch { downloading = true; try { downloadedApk = AppUpdater.downloadRelease(context, release) { progress = it } } catch (_: Exception) { Toast.makeText(context, updateError, Toast.LENGTH_SHORT).show() } finally { downloading = false } }
                    }, shape = CircleShape) { Text(tr("다운로드", "Download"), fontSize = 12.sp) }
                    else -> FilledTonalButton(onClick = {
                        scope.launch { checkingUpdate = true; try { val release = AppUpdater.fetchLatestRelease(); availableRelease = release?.takeIf { AppUpdater.isUpdateAvailable(version, it.version) }; if (availableRelease == null) Toast.makeText(context, upToDate, Toast.LENGTH_SHORT).show() } catch (_: Exception) { Toast.makeText(context, updateError, Toast.LENGTH_SHORT).show() } finally { checkingUpdate = false } }
                    }, shape = CircleShape) { Text(tr("업데이트 확인", "Check for updates"), fontSize = 12.sp) }
                }
            }
        }
        SettingsGroupCard(tr("데이터 및 백업 관리", "Data and backups")) {
            SettingAction(Icons.Rounded.Download, MaterialTheme.colorScheme.primary, tr("즐겨찾기 내보내기", "Export favorites"), tr("JSON 백업 파일로 저장", "Save a JSON backup")) { exportPayload = FavoritesBackup.encode(favorites); exportLauncher.launch("donggong_backup.json") }
            SettingsDivider()
            SettingAction(Icons.Rounded.FileUpload, MaterialTheme.colorScheme.tertiary, tr("즐겨찾기 가져오기", "Import favorites"), tr("Donggong 또는 Pupil JSON 백업 복원", "Restore a Donggong or Pupil JSON backup")) { importLauncher.launch(arrayOf("application/json", "text/*")) }
            SettingsDivider()
            SettingAction(Icons.Rounded.DeleteForever, MaterialTheme.colorScheme.error, tr("캐시 삭제", "Clear cache"), tr("이미지와 갤러리 캐시만 삭제", "Clear only image and gallery caches")) {
                scope.launch { try { DbManager.clearCache(); onClearCache(); Toast.makeText(context, cacheSuccess, Toast.LENGTH_SHORT).show() } catch (_: Exception) { Toast.makeText(context, updateError, Toast.LENGTH_SHORT).show() } }
            }
            SettingsDivider()
            SettingAction(Icons.Rounded.SettingsApplications, MaterialTheme.colorScheme.error, tr("데이터 초기화", "Reset app data"), tr("즐겨찾기, 기록, 설정을 모두 삭제", "Remove favorites, history, and settings")) { showResetDialog = true }
        }
    }

    if (showResetDialog) {
        AlertDialog(
            onDismissRequest = { showResetDialog = false },
            title = { Text(tr("데이터 초기화", "Reset app data")) },
            text = { Text(tr("즐겨찾기, 최근 본 기록, 검색 기록이 모두 영구 삭제됩니다. 계속하시겠습니까?", "Favorites, history, and searches will be permanently deleted. Continue?")) },
            confirmButton = {
                Button(onClick = {
                    scope.launch {
                        try {
                            DbManager.resetAllData()
                            onResetData()
                            showResetDialog = false
                            Toast.makeText(context, resetSuccess, Toast.LENGTH_SHORT).show()
                        } catch (_: Exception) {
                            Toast.makeText(context, updateError, Toast.LENGTH_SHORT).show()
                        }
                    }
                }) { Text(tr("초기화", "Reset")) }
            },
            dismissButton = { TextButton(onClick = { showResetDialog = false }) { Text(tr("취소", "Cancel")) } }
        )
    }
}

@Composable
private fun SettingsGroupCard(title: String, content: @Composable () -> Unit) {
    Column {
        Text(title, fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(start = 6.dp, bottom = 6.dp))
        Card(shape = RoundedCornerShape(18.dp), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer), border = BorderStroke(0.6.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.35f)), modifier = Modifier.fillMaxWidth()) {
            Column(Modifier.padding(vertical = 4.dp)) { content() }
        }
    }
}

@Composable
private fun SettingsDivider() = HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.2f), modifier = Modifier.padding(horizontal = 12.dp))

@Composable
private fun SettingsIcon(icon: ImageVector, background: Color, tint: Color) {
    Surface(shape = CircleShape, color = background, modifier = Modifier.size(34.dp)) {
        Box(contentAlignment = Alignment.Center) { Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(18.dp)) }
    }
}

@Composable
private fun SettingChoice(icon: ImageVector, title: String, value: String, options: List<Pair<String, String>>, onSelect: (String) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        SettingAction(icon, MaterialTheme.colorScheme.onSurfaceVariant, title, options.firstOrNull { it.first == value }?.second ?: value) { expanded = true }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }, shape = RoundedCornerShape(16.dp)) {
            options.forEach { (key, label) -> DropdownMenuItem(text = { Text(label, fontSize = 13.sp) }, onClick = { onSelect(key); expanded = false }) }
        }
    }
}

@Composable
private fun SettingAction(icon: ImageVector, iconTint: Color, title: String, subtitle: String, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().clickable(onClick = onClick).padding(horizontal = 12.dp, vertical = 12.dp), verticalAlignment = Alignment.CenterVertically) {
        SettingsIcon(icon, MaterialTheme.colorScheme.surfaceContainerHigh, iconTint)
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text(title, fontSize = 13.5.sp, fontWeight = FontWeight.Medium)
            Spacer(Modifier.height(2.dp))
            Text(subtitle, fontSize = 11.5.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Icon(Icons.AutoMirrored.Rounded.ArrowForwardIos, contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.4f), modifier = Modifier.size(12.dp))
    }
}
