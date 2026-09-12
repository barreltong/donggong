package com.example.donggong.ui.components

import android.widget.Toast
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.Label
import androidx.compose.material.icons.filled.Favorite
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
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.donggong.data.Favorites
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

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun TagChip(
    tag: String,
    onClick: (String) -> Unit,
    onLongClick: ((String) -> Unit)? = null,
    isFavorite: Boolean? = null,
    favorites: Favorites? = null,
    modifier: Modifier = Modifier
) {
    val info = remember(tag) { TagInfo.parse(tag) }
    val effectiveFav = isFavorite ?: (favorites?.isFavorite(info.type, info.value) == true)
    val haptic = LocalHapticFeedback.current
    val context = LocalContext.current

    val containerColor = if (effectiveFav) {
        MaterialTheme.colorScheme.primaryContainer
    } else {
        MaterialTheme.colorScheme.surfaceContainerHigh
    }
    val contentColor = if (effectiveFav) {
        MaterialTheme.colorScheme.onPrimaryContainer
    } else {
        MaterialTheme.colorScheme.onSurfaceVariant
    }
    val icon = if (effectiveFav) {
        Icons.Filled.Favorite
    } else {
        tagIcon(info.type)
    }

    Surface(
        shape = CircleShape,
        color = containerColor,
        contentColor = contentColor,
        border = BorderStroke(
            0.5.dp,
            if (effectiveFav) MaterialTheme.colorScheme.primary.copy(alpha = 0.5f)
            else MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.35f)
        ),
        modifier = modifier
            .clip(CircleShape)
            .combinedClickable(
                onClick = { onClick(tag) },
                onLongClick = if (onLongClick != null) {
                    {
                        haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                        val msg = if (effectiveFav) "즐겨찾기에서 제거되었습니다" else "즐겨찾기에 추가되었습니다"
                        Toast.makeText(context, msg, Toast.LENGTH_SHORT).show()
                        onLongClick(tag)
                    }
                } else null
            )
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 5.dp)
        ) {
            Icon(
                imageVector = icon,
                contentDescription = info.type,
                modifier = Modifier.size(13.dp),
                tint = if (effectiveFav) MaterialTheme.colorScheme.primary else contentColor.copy(alpha = 0.8f)
            )
            Spacer(modifier = Modifier.width(5.dp))
            Text(
                text = info.displayLabel,
                fontSize = 12.sp,
                fontWeight = if (effectiveFav) FontWeight.SemiBold else FontWeight.Normal,
                lineHeight = 15.sp,
                color = if (effectiveFav) MaterialTheme.colorScheme.onPrimaryContainer else MaterialTheme.colorScheme.onSurface
            )
        }
    }
}
