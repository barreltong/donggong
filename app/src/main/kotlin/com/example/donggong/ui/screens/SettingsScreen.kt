package com.example.donggong.ui.screens

import android.widget.Toast
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
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
            TopAppBar(title = { Text("설정") })
        },
        modifier = modifier
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .verticalScroll(rememberScrollState())
        ) {
            Text(
                text = "화면 및 테마",
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
            )

            ListItem(
                headlineContent = { Text("테마") },
                supportingContent = {
                    Text(
                        when (themeMode) {
                            "dark" -> "다크 모드"
                            "light" -> "라이트 모드"
                            else -> "시스템 설정"
                        }
                    )
                },
                modifier = Modifier.clickable {
                    val next = when (themeMode) {
                        "dark" -> "light"
                        "light" -> "system"
                        else -> "dark"
                    }
                    onThemeModeChange(next)
                }
            )

            ListItem(
                headlineContent = { Text("카드 표시 모드") },
                supportingContent = {
                    Text(
                        when (cardViewMode) {
                            "detailed" -> "상세 보기"
                            "compact" -> "간단히 보기"
                            else -> "그리드 보기"
                        }
                    )
                },
                modifier = Modifier.clickable {
                    val next = when (cardViewMode) {
                        "detailed" -> "compact"
                        "compact" -> "grid"
                        else -> "detailed"
                    }
                    onCardViewModeChange(next)
                }
            )

            HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))

            Text(
                text = "탐색 및 목록",
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
            )

            ListItem(
                headlineContent = { Text("목록 스크롤 방식") },
                supportingContent = {
                    Text(if (listingMode == "pagination") "페이지네이션" else "무한 스크롤")
                },
                modifier = Modifier.clickable {
                    onListingModeChange(if (listingMode == "pagination") "scroll" else "pagination")
                }
            )

            ListItem(
                headlineContent = { Text("기본 언어 필터") },
                supportingContent = { Text(defaultLanguage) },
                modifier = Modifier.clickable {
                    val next = when (defaultLanguage) {
                        "korean" -> "all"
                        "all" -> "japanese"
                        "japanese" -> "english"
                        else -> "korean"
                    }
                    onDefaultLanguageChange(next)
                }
            )

            HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))

            Text(
                text = "리더 설정",
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
            )

            ListItem(
                headlineContent = { Text("기본 리더 모드") },
                supportingContent = {
                    Text(
                        when (readerMode) {
                            "webtoon" -> "웹툰 모드"
                            "verticalPage" -> "세로 페이지"
                            "horizontalPage" -> "가로 페이지"
                            else -> "두 쪽 보기"
                        }
                    )
                },
                modifier = Modifier.clickable {
                    val next = when (readerMode) {
                        "webtoon" -> "verticalPage"
                        "verticalPage" -> "horizontalPage"
                        "horizontalPage" -> "doublePage"
                        else -> "webtoon"
                    }
                    onReaderModeChange(next)
                }
            )

            ListItem(
                headlineContent = { Text("두 쪽 보기 순서") },
                supportingContent = {
                    Text(if (doublePageOrder == "japanese") "우→좌 (일본식)" else "좌→우 (국제식)")
                },
                modifier = Modifier.clickable {
                    onDoublePageOrderChange(if (doublePageOrder == "japanese") "international" else "japanese")
                }
            )

            HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))

            Text(
                text = "앱 정보 및 업데이트",
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)
            )

            ListItem(
                headlineContent = { Text("현재 버전") },
                supportingContent = { Text("v$currentVersion") }
            )

            ListItem(
                headlineContent = { Text("업데이트 확인") },
                supportingContent = {
                    if (isDownloading) {
                        Column(modifier = Modifier.padding(top = 4.dp)) {
                            LinearProgressIndicator(
                                progress = { downloadProgress },
                                modifier = Modifier.fillMaxWidth()
                            )
                            Text("${(downloadProgress * 100).toInt()}% 다운로드 중...")
                        }
                    } else if (availableRelease != null) {
                        Text("새로운 버전 v${availableRelease?.version} 사용 가능")
                    } else {
                        Text("최신 릴리즈 확인")
                    }
                },
                trailingContent = {
                    if (isCheckingUpdate) {
                        CircularProgressIndicator()
                    } else if (downloadedApk != null) {
                        Button(onClick = {
                            AppUpdater.installApk(context, downloadedApk!!)
                        }) {
                            Text("설치")
                        }
                    } else if (availableRelease != null) {
                        Button(onClick = {
                            isDownloading = true
                            scope.launch {
                                try {
                                    val file = AppUpdater.downloadRelease(context, availableRelease!!) { prog ->
                                        downloadProgress = prog
                                    }
                                    downloadedApk = file
                                    isDownloading = false
                                    AppUpdater.installApk(context, file)
                                } catch (e: Exception) {
                                    isDownloading = false
                                    Toast.makeText(context, "다운로드 실패: ${e.message}", Toast.LENGTH_SHORT).show()
                                }
                            }
                        }) {
                            Text("다운로드")
                        }
                    }
                },
                modifier = Modifier.clickable {
                    if (!isCheckingUpdate && !isDownloading) {
                        isCheckingUpdate = true
                        scope.launch {
                            val release = AppUpdater.fetchLatestRelease()
                            isCheckingUpdate = false
                            if (release != null && AppUpdater.isUpdateAvailable(currentVersion, release.version)) {
                                availableRelease = release
                            } else {
                                Toast.makeText(context, "최신 버전을 사용 중입니다.", Toast.LENGTH_SHORT).show()
                            }
                        }
                    }
                }
            )

            HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))

            ListItem(
                headlineContent = { Text("데이터 초기화", color = Color.Red) },
                supportingContent = { Text("즐겨찾기, 최근 본 기록, 검색 기록 모두 삭제") },
                modifier = Modifier.clickable {
                    showResetDialog = true
                }
            )

            Spacer(modifier = Modifier.height(32.dp))
        }
    }

    if (showResetDialog) {
        AlertDialog(
            onDismissRequest = { showResetDialog = false },
            title = { Text("데이터 초기화") },
            text = { Text("모든 즐겨찾기, 기록, 검색어가 영구적으로 삭제됩니다. 계속하시겠습니까?") },
            confirmButton = {
                Button(
                    onClick = {
                        scope.launch {
                            DbManager.resetAllData()
                            onResetData()
                            showResetDialog = false
                            Toast.makeText(context, "초기화되었습니다.", Toast.LENGTH_SHORT).show()
                        }
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = Color.Red)
                ) {
                    Text("초기화", color = Color.White)
                }
            },
            dismissButton = {
                TextButton(onClick = { showResetDialog = false }) {
                    Text("취소")
                }
            }
        )
    }
}
