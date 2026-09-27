package com.example.donggong.ui.theme

import androidx.compose.runtime.Composable
import androidx.compose.runtime.compositionLocalOf

val LocalAppLanguage = compositionLocalOf { "ko" }

@Composable
fun tr(korean: String, english: String): String =
    if (LocalAppLanguage.current == "en") english else korean
