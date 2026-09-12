package com.example.donggong.ui.components

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.Label
import androidx.compose.material.icons.rounded.AutoStories
import androidx.compose.material.icons.rounded.Brush
import androidx.compose.material.icons.rounded.Face
import androidx.compose.material.icons.rounded.Female
import androidx.compose.material.icons.rounded.Groups
import androidx.compose.material.icons.rounded.Male
import androidx.compose.material.icons.rounded.Translate
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.donggong.data.TagInfo

fun tagIcon(type: String): ImageVector {
    return when (type) {
        "female" -> Icons.Rounded.Female
        "male" -> Icons.Rounded.Male
        "artist" -> Icons.Rounded.Brush
        "series", "parody" -> Icons.Rounded.AutoStories
        "character" -> Icons.Rounded.Face
        "group" -> Icons.Rounded.Groups
        "language" -> Icons.Rounded.Translate
        else -> Icons.AutoMirrored.Rounded.Label
    }
}

fun tagColor(type: String): Color {
    return when (type) {
        "female" -> Color(0xFFF06292)
        "male" -> Color(0xFF42A5F5)
        "artist" -> Color(0xFFBA68C8)
        "group" -> Color(0xFF4DB6AC)
        "character" -> Color(0xFFFFB74D)
        "series", "parody" -> Color(0xFF90A4AE)
        "language" -> Color(0xFFA1887F)
        else -> Color(0xFF9E9E9E)
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun TagChip(
    tag: String,
    onClick: (String) -> Unit,
    onLongClick: ((String) -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    val info = TagInfo.parse(tag)
    val color = tagColor(info.type)
    val icon = tagIcon(info.type)

    Surface(
        shape = RoundedCornerShape(8.dp),
        color = color.copy(alpha = 0.16f),
        contentColor = color,
        modifier = modifier
            .clip(RoundedCornerShape(8.dp))
            .combinedClickable(
                onClick = { onClick(tag) },
                onLongClick = { onLongClick?.invoke(tag) }
            )
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 5.dp)
        ) {
            Icon(
                imageVector = icon,
                contentDescription = info.type,
                modifier = Modifier.size(13.dp),
                tint = color
            )
            Spacer(modifier = Modifier.width(4.dp))
            Text(
                text = info.displayLabel,
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium,
                style = MaterialTheme.typography.labelMedium
            )
        }
    }
}
