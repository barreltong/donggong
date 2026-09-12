package com.example.donggong.ui.screens

import android.widget.Toast
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
import androidx.compose.material.icons.automirrored.rounded.MenuBook
import androidx.compose.material.icons.rounded.DarkMode
import androidx.compose.material.icons.rounded.DeleteForever
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
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.ListItem
import androidx.compose.material3.ListItemDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
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
import com.example.donggong.data.OtaRelease
import kotlinx.coroutines.launch
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
    onResetData: () -> Unit,
    modifier: Modifier = Modifier
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var isCheckingUpdate by remember { mutableStateOf(false) }
    var availableRelease by remember { mutableStateOf<OtaRelease?>(null) }
    var downloadProgress by remember { mutableFloatStateOf(0f) }
    var isDownloading by remember { mutableStateOf(false) }
    var downloadedApk by remember { mutableStateOf<File?>(null) }
    var showResetDialog by remember { mutableStateOf(false) }

    val currentVersion = "2.3.0"

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("설정", fontWeight = FontWeight.SemiBold) }
            )
        },
        modifier = modifier
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(horizontal = 14.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            // Section 1: Display & Theme
            SettingsGroupCard(title = "화면 및 테마") {
                SettingsItem(
                    icon = Icons.Rounded.DarkMode,
                    title = "테마 모드",
                    subtitle = when (themeMode) {
                        "dark" -> "다크 모드"
                        "light" -> "라이트 모드"
                        else -> "시스템 설정"
                    },
                    onClick = {
                        val next = when (themeMode) {
                            "dark" -> "light"
                            "light" -> "system"
                            else -> "dark"
                        }
                        onThemeModeChange(next)
                    }
                )
                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.25f))
                SettingsItem(
                    icon = Icons.Rounded.ViewAgenda,
                    title = "카드 표시 모드",
                    subtitle = when (cardViewMode) {
                        "detailed" -> "상세 보기 (태그 및 설명 포함)"
                        "compact" -> "간단히 보기"
                        else -> "그리드 보기 (격자 배열)"
                    },
                    onClick = {
                        val next = when (cardViewMode) {
                            "detailed" -> "compact"
                            "compact" -> "grid"
                            else -> "detailed"
                        }
                        onCardViewModeChange(next)
                    }
                )
            }

            // Section 2: Navigation & Reader
            SettingsGroupCard(title = "탐색 및 리더 설정") {
                SettingsItem(
                    icon = Icons.Rounded.SwapVert,
                    title = "목록 스크롤 방식",
                    subtitle = if (listingMode == "pagination") "페이지네이션 (하단 페이지 바)" else "무한 스크롤",
                    onClick = {
                        onListingModeChange(if (listingMode == "pagination") "scroll" else "pagination")
                    }
                )
                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.25f))
                SettingsItem(
                    icon = Icons.Rounded.Language,
                    title = "기본 언어 필터",
                    subtitle = when (defaultLanguage) {
                        "korean" -> "한국어 (korean)"
                        "all" -> "모든 언어 (all)"
                        "japanese" -> "일본어 (japanese)"
                        "english" -> "영어 (english)"
                        else -> defaultLanguage
                    },
                    onClick = {
                        val next = when (defaultLanguage) {
                            "korean" -> "all"
                            "all" -> "japanese"
                            "japanese" -> "english"
                            else -> "korean"
                        }
                        onDefaultLanguageChange(next)
                    }
                )
                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.25f))
                SettingsItem(
                    icon = Icons.AutoMirrored.Rounded.MenuBook,
                    title = "기본 리더 모드",
                    subtitle = when (readerMode) {
                        "webtoon" -> "웹툰 모드 (세로 연속 스크롤)"
                        "verticalPage" -> "세로 페이지 (스와이프)"
                        "horizontalPage" -> "가로 페이지 (스와이프)"
                        else -> "두 쪽 보기 (태블릿/가로)"
                    },
                    onClick = {
                        val next = when (readerMode) {
                            "webtoon" -> "verticalPage"
                            "verticalPage" -> "horizontalPage"
                            "horizontalPage" -> "doublePage"
                            else -> "webtoon"
                        }
                        onReaderModeChange(next)
                    }
                )
                HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.25f))
                SettingsItem(
                    icon = Icons.Rounded.SwapHoriz,
                    title = "두 쪽 보기 순서",
                    subtitle = if (doublePageOrder == "japanese") "우→좌 (일본식 우철)" else "좌→우 (국제식 좌철)",
                    onClick = {
                        onDoublePageOrderChange(if (doublePageOrder == "japanese") "international" else "japanese")
                    }
                )
            }

            // Section 3: App Update & Info
            SettingsGroupCard(title = "앱 정보 및 업데이트") {
                ListItem(
                    leadingContent = {
                        Surface(
                            shape = CircleShape,
                            color = MaterialTheme.colorScheme.primaryContainer,
                            modifier = Modifier.size(38.dp)
                        ) {
                            Box(contentAlignment = Alignment.Center) {
                                Icon(
                                    Icons.Rounded.SystemUpdate,
                                    contentDescription = null,
                                    tint = MaterialTheme.colorScheme.onPrimaryContainer,
                                    modifier = Modifier.size(20.dp)
                                )
                            }
                        }
                    },
                    headlineContent = { Text("동공 (Donggong)", fontWeight = FontWeight.SemiBold) },
                    supportingContent = {
                        if (isDownloading) {
                            Column(modifier = Modifier.padding(top = 6.dp)) {
                                LinearProgressIndicator(
                                    progress = { downloadProgress },
                                    modifier = Modifier.fillMaxWidth()
                                )
                                Spacer(modifier = Modifier.height(4.dp))
                                Text("${(downloadProgress * 100).toInt()}% 다운로드 중...")
                            }
                        } else if (availableRelease != null) {
                            Text("새 버전 v${availableRelease?.version} 사용 가능 (현재: v$currentVersion)")
                        } else {
                            Text("현재 버전 v$currentVersion")
                        }
                    },
                    trailingContent = {
                        if (isCheckingUpdate) {
                            CircularProgressIndicator(modifier = Modifier.size(24.dp))
                        } else if (downloadedApk != null) {
                            Button(
                                onClick = { AppUpdater.installApk(context, downloadedApk!!) },
                                shape = RoundedCornerShape(10.dp)
                            ) {
                                Text("설치")
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
                                shape = RoundedCornerShape(10.dp)
                            ) {
                                Text("다운로드")
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
                                shape = RoundedCornerShape(10.dp)
                            ) {
                                Text("확인")
                            }
                        }
                    },
                    colors = ListItemDefaults.colors(containerColor = Color.Transparent)
                )
            }

            // Section 4: Data Management
            SettingsGroupCard(title = "데이터 관리") {
                SettingsItem(
                    icon = Icons.Rounded.DeleteForever,
                    iconTint = MaterialTheme.colorScheme.error,
                    iconBg = MaterialTheme.colorScheme.errorContainer,
                    title = "데이터 및 캐시 초기화",
                    subtitle = "즐겨찾기, 최근 본 기록, 검색 기록을 모두 삭제합니다",
                    onClick = { showResetDialog = true }
                )
            }

            Spacer(modifier = Modifier.height(24.dp))
        }

        if (showResetDialog) {
            AlertDialog(
                onDismissRequest = { showResetDialog = false },
                title = { Text("데이터 초기화", fontWeight = FontWeight.Bold) },
                text = { Text("즐겨찾기, 최근 본 기록, 검색 기록이 모두 영구 삭제됩니다. 계속하시겠습니까?") },
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
                        shape = RoundedCornerShape(10.dp)
                    ) {
                        Text("초기화")
                    }
                },
                dismissButton = {
                    TextButton(onClick = { showResetDialog = false }) {
                        Text("취소")
                    }
                },
                shape = RoundedCornerShape(20.dp)
            )
        }
    }
}

@Composable
fun SettingsGroupCard(
    title: String,
    content: @Composable () -> Unit
) {
    Column {
        Text(
            text = title,
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.primary,
            modifier = Modifier.padding(start = 6.dp, bottom = 6.dp, top = 4.dp)
        )
        Card(
            shape = RoundedCornerShape(18.dp),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
            border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.3f)),
            modifier = Modifier.fillMaxWidth()
        ) {
            Column {
                content()
            }
        }
    }
}

@Composable
fun SettingsItem(
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
                modifier = Modifier.size(38.dp)
            ) {
                Box(contentAlignment = Alignment.Center) {
                    Icon(
                        imageVector = icon,
                        contentDescription = null,
                        tint = iconTint,
                        modifier = Modifier.size(20.dp)
                    )
                }
            }
        },
        headlineContent = {
            Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Medium)
        },
        supportingContent = {
            Text(subtitle, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        },
        colors = ListItemDefaults.colors(containerColor = Color.Transparent),
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .clickable(onClick = onClick)
    )
}
