package com.example.donggong

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.outlined.History
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material.icons.rounded.History
import androidx.compose.material.icons.rounded.Home
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.example.donggong.data.DbManager
import com.example.donggong.data.Favorites
import com.example.donggong.ui.screens.DetailScreen
import com.example.donggong.ui.screens.FavoritesScreen
import com.example.donggong.ui.screens.HistoryScreen
import com.example.donggong.ui.screens.HomeScreen
import com.example.donggong.ui.screens.ReaderScreen
import com.example.donggong.ui.screens.SettingsScreen
import com.example.donggong.ui.theme.DonggongTheme
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            DonggongMainApp()
        }
    }
}

@Composable
fun DonggongMainApp() {
    val navController = rememberNavController()
    val scope = rememberCoroutineScope()

    var favorites by remember { mutableStateOf(Favorites()) }
    var themeMode by remember { mutableStateOf("dark") }
    var readerMode by remember { mutableStateOf("verticalPage") }
    var doublePageOrder by remember { mutableStateOf("japanese") }
    var listingMode by remember { mutableStateOf("scroll") }
    var cardViewMode by remember { mutableStateOf("detailed") }
    var defaultLanguage by remember { mutableStateOf("korean") }

    LaunchedEffect(Unit) {
        val settings = DbManager.loadSettings()
        themeMode = settings["themeModeKey"] ?: settings["themeMode"] ?: "dark"
        readerMode = settings["readerMode"] ?: "verticalPage"
        doublePageOrder = settings["doublePageOrder"] ?: "japanese"
        listingMode = settings["listingMode"] ?: "scroll"
        cardViewMode = settings["cardViewMode"] ?: "detailed"
        defaultLanguage = settings["defaultLanguage"] ?: "korean"
        favorites = DbManager.loadFavorites()
    }

    fun updateSetting(key: String, value: String) {
        scope.launch {
            DbManager.saveSetting(key, value)
        }
    }

    DonggongTheme(themeMode = themeMode) {
        val navBackStackEntry by navController.currentBackStackEntryAsState()
        val currentRoute = navBackStackEntry?.destination?.route ?: "home"

        val showBottomBar = currentRoute in listOf("home", "favorites", "history", "settings")

        Scaffold(
            bottomBar = {
                if (showBottomBar) {
                    NavigationBar(
                        containerColor = MaterialTheme.colorScheme.surfaceContainer,
                        tonalElevation = 3.dp
                    ) {
                        val navItemColors = NavigationBarItemDefaults.colors(
                            indicatorColor = MaterialTheme.colorScheme.primaryContainer,
                            selectedIconColor = MaterialTheme.colorScheme.onPrimaryContainer,
                            selectedTextColor = MaterialTheme.colorScheme.primary,
                            unselectedIconColor = MaterialTheme.colorScheme.onSurfaceVariant,
                            unselectedTextColor = MaterialTheme.colorScheme.onSurfaceVariant
                        )

                        NavigationBarItem(
                            selected = currentRoute == "home",
                            onClick = {
                                navController.navigate("home") {
                                    popUpTo(navController.graph.findStartDestination().id) {
                                        saveState = true
                                    }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            },
                            icon = {
                                Icon(
                                    imageVector = if (currentRoute == "home") Icons.Rounded.Home else Icons.Outlined.Home,
                                    contentDescription = "홈"
                                )
                            },
                            label = { Text("홈", fontWeight = if (currentRoute == "home") FontWeight.Bold else FontWeight.Normal) },
                            colors = navItemColors
                        )
                        NavigationBarItem(
                            selected = currentRoute == "favorites",
                            onClick = {
                                navController.navigate("favorites") {
                                    popUpTo(navController.graph.findStartDestination().id) {
                                        saveState = true
                                    }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            },
                            icon = {
                                Icon(
                                    imageVector = if (currentRoute == "favorites") Icons.Rounded.Favorite else Icons.Outlined.FavoriteBorder,
                                    contentDescription = "즐겨찾기"
                                )
                            },
                            label = { Text("즐겨찾기", fontWeight = if (currentRoute == "favorites") FontWeight.Bold else FontWeight.Normal) },
                            colors = navItemColors
                        )
                        NavigationBarItem(
                            selected = currentRoute == "history",
                            onClick = {
                                navController.navigate("history") {
                                    popUpTo(navController.graph.findStartDestination().id) {
                                        saveState = true
                                    }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            },
                            icon = {
                                Icon(
                                    imageVector = if (currentRoute == "history") Icons.Rounded.History else Icons.Outlined.History,
                                    contentDescription = "기록"
                                )
                            },
                            label = { Text("기록", fontWeight = if (currentRoute == "history") FontWeight.Bold else FontWeight.Normal) },
                            colors = navItemColors
                        )
                        NavigationBarItem(
                            selected = currentRoute == "settings",
                            onClick = {
                                navController.navigate("settings") {
                                    popUpTo(navController.graph.findStartDestination().id) {
                                        saveState = true
                                    }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            },
                            icon = {
                                Icon(
                                    imageVector = if (currentRoute == "settings") Icons.Rounded.Settings else Icons.Outlined.Settings,
                                    contentDescription = "설정"
                                )
                            },
                            label = { Text("설정", fontWeight = if (currentRoute == "settings") FontWeight.Bold else FontWeight.Normal) },
                            colors = navItemColors
                        )
                    }
                }
            },
            modifier = Modifier.fillMaxSize()
        ) { innerPadding ->
            NavHost(
                navController = navController,
                startDestination = "home",
                modifier = Modifier.padding(innerPadding)
            ) {
                composable("home") {
                    HomeScreen(
                        favorites = favorites,
                        onFavoriteToggle = { type, value, gallery ->
                            scope.launch {
                                val isFav = favorites.isFavorite(type, value)
                                if (isFav) {
                                    DbManager.removeFavorite(type, value)
                                } else {
                                    DbManager.addFavorite(type, value)
                                    if (type == "gallery" && gallery != null) {
                                        DbManager.cacheGallery(gallery)
                                    }
                                }
                                favorites = DbManager.loadFavorites()
                            }
                        },
                        onGalleryClick = { id ->
                            navController.navigate("detail/$id")
                        },
                        listingMode = listingMode,
                        cardViewMode = cardViewMode,
                        onCardViewModeChange = {
                            cardViewMode = it
                            updateSetting("cardViewMode", it)
                        },
                        defaultLanguage = defaultLanguage
                    )
                }

                composable(
                    route = "detail/{galleryId}",
                    arguments = listOf(navArgument("galleryId") { type = NavType.LongType })
                ) { backStackEntry ->
                    val id = backStackEntry.arguments?.getLong("galleryId") ?: 0L
                    DetailScreen(
                        galleryId = id,
                        favorites = favorites,
                        onFavoriteToggle = { type, value, gallery ->
                            scope.launch {
                                val isFav = favorites.isFavorite(type, value)
                                if (isFav) {
                                    DbManager.removeFavorite(type, value)
                                } else {
                                    DbManager.addFavorite(type, value)
                                    if (type == "gallery" && gallery != null) {
                                        DbManager.cacheGallery(gallery)
                                    }
                                }
                                favorites = DbManager.loadFavorites()
                            }
                        },
                        onBack = { navController.popBackStack() },
                        onStartReader = { targetId, page ->
                            navController.navigate("reader/$targetId?page=$page")
                        },
                        onSearchTag = { tag ->
                            navController.popBackStack("home", false)
                            // Search tag on home
                        }
                    )
                }

                composable(
                    route = "reader/{galleryId}?page={page}",
                    arguments = listOf(
                        navArgument("galleryId") { type = NavType.LongType },
                        navArgument("page") {
                            type = NavType.IntType
                            defaultValue = 0
                        }
                    )
                ) { backStackEntry ->
                    val id = backStackEntry.arguments?.getLong("galleryId") ?: 0L
                    val page = backStackEntry.arguments?.getInt("page") ?: 0
                    ReaderScreen(
                        galleryId = id,
                        initialPage = page,
                        initialMode = readerMode,
                        initialDoublePageOrder = doublePageOrder,
                        onBack = { navController.popBackStack() }
                    )
                }

                composable("favorites") {
                    FavoritesScreen(
                        favorites = favorites,
                        onFavoriteToggle = { type, value, gallery ->
                            scope.launch {
                                val isFav = favorites.isFavorite(type, value)
                                if (isFav) {
                                    DbManager.removeFavorite(type, value)
                                } else {
                                    DbManager.addFavorite(type, value)
                                    if (type == "gallery" && gallery != null) {
                                        DbManager.cacheGallery(gallery)
                                    }
                                }
                                favorites = DbManager.loadFavorites()
                            }
                        },
                        onFavoritesImported = { imported ->
                            favorites = imported
                        },
                        onGalleryClick = { id ->
                            navController.navigate("detail/$id")
                        },
                        onSearchTag = { tag ->
                            navController.navigate("home")
                        }
                    )
                }

                composable("history") {
                    HistoryScreen(
                        favorites = favorites,
                        onFavoriteToggle = { type, value, gallery ->
                            scope.launch {
                                val isFav = favorites.isFavorite(type, value)
                                if (isFav) {
                                    DbManager.removeFavorite(type, value)
                                } else {
                                    DbManager.addFavorite(type, value)
                                }
                                favorites = DbManager.loadFavorites()
                            }
                        },
                        onGalleryClick = { id ->
                            navController.navigate("detail/$id")
                        },
                        onSearchTag = { tag ->
                            navController.navigate("home")
                        }
                    )
                }

                composable("settings") {
                    SettingsScreen(
                        themeMode = themeMode,
                        onThemeModeChange = {
                            themeMode = it
                            updateSetting("themeModeKey", it)
                        },
                        readerMode = readerMode,
                        onReaderModeChange = {
                            readerMode = it
                            updateSetting("readerMode", it)
                        },
                        doublePageOrder = doublePageOrder,
                        onDoublePageOrderChange = {
                            doublePageOrder = it
                            updateSetting("doublePageOrder", it)
                        },
                        listingMode = listingMode,
                        onListingModeChange = {
                            listingMode = it
                            updateSetting("listingMode", it)
                        },
                        cardViewMode = cardViewMode,
                        onCardViewModeChange = {
                            cardViewMode = it
                            updateSetting("cardViewMode", it)
                        },
                        defaultLanguage = defaultLanguage,
                        onDefaultLanguageChange = {
                            defaultLanguage = it
                            updateSetting("defaultLanguage", it)
                        },
                        onResetData = {
                            favorites = Favorites()
                        }
                    )
                }
            }
        }
    }
}
