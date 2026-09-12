package com.example.donggong.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Clear
import androidx.compose.material.icons.rounded.History
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.donggong.core.DonggongBridge
import com.example.donggong.data.Favorites
import com.example.donggong.data.TagSuggestion
import kotlinx.coroutines.delay

@Composable
fun DonggongSearchBar(
    query: String,
    onQueryChange: (String) -> Unit,
    onSearch: (String) -> Unit,
    favorites: Favorites,
    recentSearches: List<String>,
    onRemoveRecentSearch: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    var isFocused by remember { mutableStateOf(false) }
    var suggestions by remember { mutableStateOf<List<TagSuggestion>>(emptyList()) }
    val focusManager = LocalFocusManager.current

    LaunchedEffect(query) {
        if (query.isNotBlank() && isFocused) {
            delay(250) // debounce
            val lastWord = query.trim().split(Regex("\\s+")).lastOrNull() ?: ""
            val clean = lastWord.substringAfter(':')
            if (clean.length >= 2) {
                suggestions = DonggongBridge.getTagSuggestions(clean)
            } else {
                suggestions = emptyList()
            }
        } else {
            suggestions = emptyList()
        }
    }

    Column(modifier = modifier.fillMaxWidth()) {
        OutlinedTextField(
            value = query,
            onValueChange = onQueryChange,
            placeholder = { Text("태그, 작가, 작품 검색...") },
            leadingIcon = {
                Icon(Icons.Rounded.Search, contentDescription = "Search")
            },
            trailingIcon = {
                if (query.isNotEmpty()) {
                    IconButton(onClick = {
                        onQueryChange("")
                        suggestions = emptyList()
                    }) {
                        Icon(Icons.Rounded.Clear, contentDescription = "Clear")
                    }
                }
            },
            singleLine = true,
            shape = RoundedCornerShape(24.dp),
            colors = OutlinedTextFieldDefaults.colors(
                focusedContainerColor = MaterialTheme.colorScheme.surfaceContainerHigh,
                unfocusedContainerColor = MaterialTheme.colorScheme.surfaceContainer,
                focusedBorderColor = MaterialTheme.colorScheme.primary,
                unfocusedBorderColor = MaterialTheme.colorScheme.outlineVariant
            ),
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
            keyboardActions = KeyboardActions(
                onSearch = {
                    focusManager.clearFocus()
                    onSearch(query)
                }
            ),
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 4.dp)
                .onFocusChanged { isFocused = it.isFocused }
        )

        // Favorite tags quick filter row
        if (!isFocused && favorites.allChips.isNotEmpty()) {
            LazyRow(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 12.dp, vertical = 4.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                items(favorites.allChips) { chip ->
                    TagChip(
                        tag = chip,
                        onClick = { tag ->
                            onQueryChange(tag)
                            onSearch(tag)
                        }
                    )
                }
            }
        }

        // Suggestions overlay
        AnimatedVisibility(visible = isFocused && (suggestions.isNotEmpty() || (query.isEmpty() && recentSearches.isNotEmpty()))) {
            Surface(
                shape = RoundedCornerShape(16.dp),
                color = MaterialTheme.colorScheme.surfaceContainerHigh,
                tonalElevation = 6.dp,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 12.dp, vertical = 4.dp)
            ) {
                Column(modifier = Modifier.padding(8.dp)) {
                    if (query.isEmpty() && recentSearches.isNotEmpty()) {
                        Text(
                            text = "최근 검색",
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                        )
                        recentSearches.take(5).forEach { recent ->
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.SpaceBetween,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable {
                                        focusManager.clearFocus()
                                        onQueryChange(recent)
                                        onSearch(recent)
                                    }
                                    .padding(horizontal = 8.dp, vertical = 6.dp)
                            ) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Icon(Icons.Rounded.History, contentDescription = null, modifier = Modifier.size(16.dp))
                                    Text(text = " $recent", fontSize = 14.sp)
                                }
                                IconButton(
                                    onClick = { onRemoveRecentSearch(recent) },
                                    modifier = Modifier.size(20.dp)
                                ) {
                                    Icon(Icons.Rounded.Clear, contentDescription = "Delete", modifier = Modifier.size(14.dp))
                                }
                            }
                        }
                    }

                    if (suggestions.isNotEmpty()) {
                        Text(
                            text = "추천 태그",
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                        )
                        suggestions.take(6).forEach { sugg ->
                            val fullTag = if (sugg.type == "tag") sugg.tag else "${sugg.type}:${sugg.tag}"
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.SpaceBetween,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable {
                                        focusManager.clearFocus()
                                        val parts = query.trim().split(Regex("\\s+")).toMutableList()
                                        if (parts.isNotEmpty()) parts.removeAt(parts.size - 1)
                                        parts.add(fullTag.replace(' ', '_'))
                                        val newQuery = parts.joinToString(" ")
                                        onQueryChange(newQuery)
                                        onSearch(newQuery)
                                    }
                                    .padding(horizontal = 8.dp, vertical = 6.dp)
                            ) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Icon(tagIcon(sugg.type), contentDescription = null, tint = tagColor(sugg.type), modifier = Modifier.size(16.dp))
                                    Text(text = " $fullTag", fontSize = 14.sp)
                                }
                                Text(
                                    text = "${sugg.count}개",
                                    fontSize = 12.sp,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}
