package com.example.donggong.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.automirrored.rounded.ArrowForward
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
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

    Surface(
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surfaceContainerHigh,
        modifier = modifier
            .fillMaxWidth()
            .padding(8.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 8.dp, vertical = 4.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row {
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

            TextButton(onClick = { /* Jump to page dialog can open here */ }) {
                Text(
                    text = "$currentPage / $totalPages",
                    style = MaterialTheme.typography.titleMedium,
                    fontSize = 15.sp
                )
            }

            Row {
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
