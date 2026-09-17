package com.example.donggong.ui.components

import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.calculateCentroid
import androidx.compose.foundation.gestures.calculatePan
import androidx.compose.foundation.gestures.calculateZoom
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.PointerInputChange
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.unit.IntSize
import kotlin.math.abs

private const val MIN_ZOOM_SCALE = 1f
private const val MAX_ZOOM_SCALE = 5f

/**
 * Pinch-to-zoom and pan wrapper for a single reader page.
 *
 * Two-pointer gestures are consumed here so the enclosing pager or list never sees
 * them, which is what keeps a pinch from turning into a page scroll. A single
 * pointer is only consumed while zoomed in and still able to move on the dominant
 * axis, so normal scrolling keeps working at rest and at the pan bounds.
 *
 * [resetKey] returns the page to fit when it changes, so a recycled slot never
 * inherits the previous page's zoom.
 */
@Composable
fun ZoomableBox(
    modifier: Modifier = Modifier,
    resetKey: Any? = Unit,
    content: @Composable BoxScope.() -> Unit
) {
    var scale by remember(resetKey) { mutableFloatStateOf(MIN_ZOOM_SCALE) }
    var offset by remember(resetKey) { mutableStateOf(Offset.Zero) }
    var size by remember { mutableStateOf(IntSize.Zero) }

    fun clamp(target: Offset, current: Float): Offset {
        val boundX = (size.width * (current - 1f) / 2f).coerceAtLeast(0f)
        val boundY = (size.height * (current - 1f) / 2f).coerceAtLeast(0f)
        return Offset(
            target.x.coerceIn(-boundX, boundX),
            target.y.coerceIn(-boundY, boundY)
        )
    }

    Box(
        modifier = modifier
            .onSizeChanged { size = it }
            .pointerInput(Unit) {
                awaitEachGesture {
                    awaitFirstDown(requireUnconsumed = false)

                    while (true) {
                        val event = awaitPointerEvent()
                        val pressed = event.changes.count { it.pressed }
                        if (pressed == 0) break

                        if (pressed >= 2) {
                            val zoomChange = event.calculateZoom()
                            val panChange = event.calculatePan()
                            if (zoomChange == 1f && panChange == Offset.Zero) continue

                            val newScale = (scale * zoomChange)
                                .coerceIn(MIN_ZOOM_SCALE, MAX_ZOOM_SCALE)
                            // Hold the point under the fingers steady while scaling.
                            val centroid = event.calculateCentroid(useCurrent = true)
                            val pivot = centroid - Offset(size.width / 2f, size.height / 2f)
                            val scaled = (offset - pivot) * (newScale / scale) + pivot

                            scale = newScale
                            offset = clamp(scaled + panChange, newScale)
                            consumePressed(event.changes)
                        } else if (scale > MIN_ZOOM_SCALE) {
                            val panChange = event.calculatePan()
                            if (panChange == Offset.Zero) continue

                            val previous = offset
                            val clamped = clamp(previous + panChange, scale)
                            offset = clamped

                            // Release the gesture once the image cannot travel further
                            // on the dominant axis; the pager takes over from there.
                            val moved = if (abs(panChange.x) > abs(panChange.y)) {
                                clamped.x != previous.x
                            } else {
                                clamped.y != previous.y
                            }
                            if (moved) consumePressed(event.changes)
                        }
                    }
                }
            }
    ) {
        Box(
            modifier = Modifier.graphicsLayer {
                scaleX = scale
                scaleY = scale
                translationX = offset.x
                translationY = offset.y
                transformOrigin = TransformOrigin.Center
            },
            content = content
        )
    }
}

private fun consumePressed(changes: List<PointerInputChange>) {
    changes.forEach { if (it.pressed) it.consume() }
}
