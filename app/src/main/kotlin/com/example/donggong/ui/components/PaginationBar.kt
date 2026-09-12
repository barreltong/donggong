package com.example.donggong.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.automirrored.rounded.ArrowForward
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun PaginationBar(
    currentPage: Int,
    totalCount: Int,
    pageSize: Int = 25,
    onPageSelected: (Int) -> Unit,
    modifier: Modifier = Modifier
) {
    val totalPages = maxOf(1, (totalCount + pageSize - 1) / pageSize)
    var showJumpDialog by remember { mutableStateOf(false) }
    var targetPageInput by remember { mutableStateOf("") }

    if (showJumpDialog) {
        AlertDialog(
            onDismissRequest = { showJumpDialog = false },
            title = { Text("페이지 이동", style = MaterialTheme.typography.titleLarge) },
            text = {
                OutlinedTextField(
                    value = targetPageInput,
                    onValueChange = { targetPageInput = it.filter { c -> c.isDigit() } },
                    label = { Text("이동할 페이지 (1 ~ $totalPages)") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier.fillMaxWidth()
                )
            },
            confirmButton = {
                FilledTonalButton(
                    onClick = {
                        val p = targetPageInput.toIntOrNull()
                        if (p != null && p in 1..totalPages) {
                            onPageSelected(p)
                            showJumpDialog = false
                        }
                    }
                ) {
                    Text("이동")
                }
            },
            dismissButton = {
                TextButton(onClick = { showJumpDialog = false }) {
                    Text("취소")
                }
            },
            shape = RoundedCornerShape(20.dp)
        )
    }

    Surface(
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surfaceContainer,
        tonalElevation = 2.dp,
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 6.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 6.dp, vertical = 2.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                IconButton(
                    onClick = { onPageSelected(1) },
                    enabled = currentPage > 1
                ) {
                    Icon(Icons.AutoMirrored.Rounded.ArrowBack, contentDescription = "First Page")
                }
                IconButton(
                    onClick = { onPageSelected(currentPage - 1) },
                    enabled = currentPage > 1
                ) {
                    Icon(Icons.AutoMirrored.Rounded.KeyboardArrowLeft, contentDescription = "Previous Page")
                }
            }

            TextButton(
                onClick = {
                    targetPageInput = currentPage.toString()
                    showJumpDialog = true
                }
            ) {
                Text(
                    text = "$currentPage / $totalPages",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.primary,
                    fontSize = 15.sp
                )
            }

            Row(verticalAlignment = Alignment.CenterVertically) {
                IconButton(
                    onClick = { onPageSelected(currentPage + 1) },
                    enabled = currentPage < totalPages
                ) {
                    Icon(Icons.AutoMirrored.Rounded.KeyboardArrowRight, contentDescription = "Next Page")
                }
                IconButton(
                    onClick = { onPageSelected(totalPages) },
                    enabled = currentPage < totalPages
                ) {
                    Icon(Icons.AutoMirrored.Rounded.ArrowForward, contentDescription = "Last Page")
                }
            }
        }
    }
}
