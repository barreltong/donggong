import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../core/hitomi.dart';
import '../core/app_state.dart';
import '../core/i18n.dart';
import '../core/tag_utils.dart';
import '../network/http.dart';
import 'app_notification.dart';
import 'detail.dart';

class PagedCollectionController<T> extends ChangeNotifier {
  PagedCollectionController({required this.pageSize});

  final int pageSize;
  List<T> _sourceItems = [];
  List<T> _visibleItems = [];
  int _currentPage = 1;
  int _totalCount = 0;

  List<T> get sourceItems => _sourceItems;
  List<T> get visibleItems => _visibleItems;
  int get currentPage => _currentPage;
  int get totalCount => _totalCount;
  bool get hasVisibleItems => _visibleItems.isNotEmpty;
  bool get canLoadMore => _visibleItems.length < _totalCount;

  void replaceAll(
    List<T> items, {
    required int totalCount,
    int currentPage = 1,
    required String listingMode,
  }) {
    _sourceItems = List<T>.from(items);
    _totalCount = totalCount;
    _currentPage = currentPage;
    _rebuildVisible(listingMode);
  }

  void appendPage(
    List<T> items, {
    required int totalCount,
    required String listingMode,
  }) {
    _sourceItems.addAll(items);
    _totalCount = totalCount;
    _currentPage += 1;
    _rebuildVisible(listingMode);
  }

  void applyListingMode(String listingMode, {int? targetPage}) {
    if (targetPage != null) {
      _currentPage = targetPage;
    }
    _rebuildVisible(listingMode);
  }

  void clear({bool notify = true}) {
    _sourceItems = [];
    _visibleItems = [];
    _currentPage = 1;
    _totalCount = 0;
    if (notify) {
      notifyListeners();
    }
  }

  void _rebuildVisible(String listingMode) {
    if (listingMode == 'pagination') {
      _visibleItems = List<T>.from(_sourceItems);
    } else {
      final end = (_currentPage * pageSize).clamp(0, _sourceItems.length);
      _visibleItems = _sourceItems.sublist(0, end);
    }
    notifyListeners();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gallery Grid (Common Grid)
// ─────────────────────────────────────────────────────────────────────────────
class GalleryGrid extends StatelessWidget {
  final List<Gallery> galleries;
  final bool isLoading;
  final ScrollController? scrollController;
  final EdgeInsetsGeometry padding;
  final Function(Gallery)? onDismissed;
  final Function(Gallery)? onRetry;
  final void Function(String query)? onSearchTag;

  const GalleryGrid({
    super.key,
    required this.galleries,
    this.isLoading = false,
    this.scrollController,
    this.padding = const EdgeInsets.all(16),
    this.onDismissed,
    this.onRetry,
    this.onSearchTag,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance.cardViewMode,
      builder: (context, _) {
        final isDetailed = AppState.instance.cardViewMode.value == 'detailed';

        if (isDetailed) {
          return ListView.separated(
            controller: scrollController,
            padding: padding,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            itemCount: galleries.length + (isLoading ? 5 : 0),
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index >= galleries.length) {
                return const _DetailedShimmer();
              }
              final gallery = galleries[index];
              final card = GalleryCard(
                gallery: gallery,
                onTap: () => _onTap(context, gallery),
                onLongPress: () => _onLongPress(context, gallery),
              );

              if (onDismissed != null) {
                return Dismissible(
                  key: Key('detailed_${gallery.id}'),
                  direction: DismissDirection.endToStart,
                  background: _buildDismissBackground(),
                  onDismissed: (_) => onDismissed!(gallery),
                  child: card,
                );
              }
              return card;
            },
          );
        } else {
          return GridView.builder(
            controller: scrollController,
            padding: padding,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 180,
              childAspectRatio: 0.72,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: galleries.length + (isLoading ? 10 : 0),
            itemBuilder: (context, index) {
              if (index >= galleries.length) {
                return const _ThumbnailShimmer();
              }
              final gallery = galleries[index];
              final card = GalleryCard(
                gallery: gallery,
                onTap: () => _onTap(context, gallery),
                onLongPress: () => _onLongPress(context, gallery),
              );

              if (onDismissed != null) {
                return Dismissible(
                  key: Key('thumb_${gallery.id}'),
                  direction: DismissDirection.endToStart,
                  background: _buildDismissBackground(),
                  onDismissed: (_) => onDismissed!(gallery),
                  child: card,
                );
              }
              return card;
            },
          );
        }
      },
    );
  }

  Widget _buildDismissBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
    );
  }

  void _onTap(BuildContext context, Gallery gallery) {
    if (gallery.isError) {
      if (onRetry != null) onRetry!(gallery);
      return;
    }
    Navigator.pushNamed(context, '/reader', arguments: {'id': gallery.id});
    AppState.instance.addToHistory(gallery);
  }

  void _onLongPress(BuildContext context, Gallery gallery) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          DetailBottomSheet(galleryId: gallery.id, onSearchTag: onSearchTag),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading Overlay (Blocking UI during loading)
// ─────────────────────────────────────────────────────────────────────────────
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: AbsorbPointer(
              absorbing: true,
              child: AnimatedOpacity(
                opacity: isLoading ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  color: Theme.of(
                    context,
                  ).colorScheme.surface.withValues(alpha: 0.7),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const CircularProgressIndicator(),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading Shimmers
// ─────────────────────────────────────────────────────────────────────────────
class _ThumbnailShimmer extends StatelessWidget {
  const _ThumbnailShimmer();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: colorScheme.surfaceContainerHigh,
      highlightColor: colorScheme.surfaceContainer,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _DetailedShimmer extends StatelessWidget {
  const _DetailedShimmer();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: colorScheme.surfaceContainerHigh,
      highlightColor: colorScheme.surfaceContainer,
      child: Container(
        height: 145,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hitomi Image Widget (Infinite Retry)
// ─────────────────────────────────────────────────────────────────────────────
class HitomiImage extends StatefulWidget {
  final String? imageHash;
  final String url;
  final BoxFit fit;
  final Alignment alignment;
  final double? width;
  final double? height;
  final bool showLoadingPlaceholder;
  final bool showErrorIndicator;

  const HitomiImage({
    super.key,
    this.imageHash,
    required this.url,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.width,
    this.height,
    this.showLoadingPlaceholder = true,
    this.showErrorIndicator = true,
  });

  @override
  State<HitomiImage> createState() => _HitomiImageState();
}

class _HitomiImageState extends State<HitomiImage> {
  late String _currentUrl;
  int _retryCount = 0;
  bool _isRefreshingUrl = false;
  bool _didRefreshFromHash = false;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;
  }

  @override
  void didUpdateWidget(covariant HitomiImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url ||
        widget.imageHash != oldWidget.imageHash) {
      _currentUrl = widget.url;
      _retryCount = 0;
      _isRefreshingUrl = false;
      _didRefreshFromHash = false;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _retry() {
    if (_isRefreshingUrl) return;
    if (_isDisposed) return;
    Future.delayed(const Duration(seconds: 2), () {
      if (!_isDisposed) {
        setState(() {
          _retryCount++;
        });
      }
    });
  }

  Future<void> _refreshUrlFromHash() async {
    if (_isDisposed || _isRefreshingUrl || widget.imageHash == null) return;

    _isRefreshingUrl = true;
    try {
      final refreshedUrl = await HitomiManager.instance.resolveImageUrl(
        widget.imageHash!,
        forceRefresh: true,
      );
      if (_isDisposed) return;

      setState(() {
        _currentUrl = refreshedUrl;
        _retryCount = 0;
        _didRefreshFromHash = true;
      });
    } catch (_) {
      if (_isDisposed) return;
      _retry();
    } finally {
      _isRefreshingUrl = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (_currentUrl.isEmpty) {
      return Container(
        width: widget.width,
        height: widget.height,
        color: colorScheme.surfaceContainerHigh,
        child: const Icon(Icons.broken_image_rounded, size: 24),
      );
    }

    return CachedNetworkImage(
      key: ValueKey('$_currentUrl|$_retryCount'),
      imageUrl: _currentUrl,
      width: widget.width,
      height: widget.height,
      httpHeaders: HttpClient.defaultHeaders,
      fit: widget.fit,
      alignment: widget.alignment,
      placeholder: (context, url) => widget.showLoadingPlaceholder
          ? Shimmer.fromColors(
              baseColor: colorScheme.surfaceContainerHigh,
              highlightColor: colorScheme.surfaceContainer,
              child: Container(color: Colors.white),
            )
          : const SizedBox.expand(),
      errorWidget: (context, url, error) {
        if (!_didRefreshFromHash && widget.imageHash != null) {
          _refreshUrlFromHash();
        } else {
          _retry();
        }
        return widget.showErrorIndicator
            ? Container(
                color: colorScheme.surfaceContainerHigh,
                child: const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            : const SizedBox.expand();
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gallery Card
// ─────────────────────────────────────────────────────────────────────────────
class GalleryCard extends StatelessWidget {
  final Gallery gallery;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const GalleryCard({
    super.key,
    required this.gallery,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    if (gallery.isLoading) {
      final mode = AppState.instance.cardViewMode.value;
      if (mode == 'detailed') {
        return const _DetailedShimmer();
      }
      return const _ThumbnailShimmer();
    }

    if (gallery.isError) {
      return Card(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        elevation: 0,
        child: InkWell(
          onTap: onTap, // Handled by parent to retry
          borderRadius: BorderRadius.circular(12),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.refresh_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap to Retry',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final mode = AppState.instance.cardViewMode.value;
    if (mode == 'detailed') {
      return RepaintBoundary(
        child: _DetailedCard(
          key: ValueKey('detailed_${gallery.id}'),
          gallery: gallery,
          onTap: onTap ?? () {},
          onLongPress: onLongPress,
        ),
      );
    }
    return RepaintBoundary(
      child: _ThumbnailCard(
        key: ValueKey('thumb_${gallery.id}'),
        gallery: gallery,
        onTap: onTap ?? () {},
        onLongPress: onLongPress,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Thumbnail Card (Grid)
// ─────────────────────────────────────────────────────────────────────────────
class _ThumbnailCard extends StatelessWidget {
  final Gallery gallery;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ThumbnailCard({
    super.key,
    required this.gallery,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l = L.of(context);

    return ListenableBuilder(
      listenable: AppState.instance.favorites,
      builder: (context, _) {
        final isFav = AppState.instance.favorites.value.isFavorite(
          'gallery',
          gallery.id,
        );

        return Card(
          clipBehavior: Clip.antiAlias,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          color: colorScheme.surfaceContainer,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Stack(
              fit: StackFit.expand,
              children: [
                HitomiImage(url: gallery.thumbnail, fit: BoxFit.cover),

                // Gradient Overlay
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.1),
                          Colors.black.withValues(alpha: 0.8),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),

                // Info Overlays
                Positioned(
                  top: 8,
                  left: 8,
                  child: Row(
                    children: [
                      _buildOverlayChip(gallery.type),
                      if (gallery.language != null) ...[
                        const SizedBox(width: 4),
                        _buildOverlayChip(gallery.language!),
                      ],
                    ],
                  ),
                ),

                if (isFav)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        size: 14,
                        color: Colors.redAccent,
                      ),
                    ),
                  ),

                // Title & Artist
                Positioned(
                  bottom: 10,
                  left: 10,
                  right: 10,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        gallery.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        gallery.artists.isNotEmpty
                            ? gallery.artists.join(', ')
                            : l.na,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOverlayChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detailed Card (List)
// ─────────────────────────────────────────────────────────────────────────────
class _DetailedCard extends StatelessWidget {
  final Gallery gallery;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _DetailedCard({
    super.key,
    required this.gallery,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l = L.of(context);

    return ListenableBuilder(
      listenable: AppState.instance.favorites,
      builder: (context, _) {
        final isFav = AppState.instance.favorites.value.isFavorite(
          'gallery',
          gallery.id,
        );

        return Container(
          height: 145,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: theme.brightness == Brightness.light
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Card(
            elevation: 0,
            color: colorScheme.surfaceContainer,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 3 / 4,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        HitomiImage(url: gallery.thumbnail, fit: BoxFit.cover),
                        if (isFav)
                          Positioned(
                            bottom: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.4),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.favorite_rounded,
                                size: 12,
                                color: Colors.redAccent,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            gallery.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildInfoRow(
                            Icons.brush_rounded,
                            gallery.artists,
                            colorScheme,
                            theme,
                            l,
                          ),
                          const SizedBox(height: 6),
                          _buildInfoRow(
                            Icons.groups_rounded,
                            gallery.groups,
                            colorScheme,
                            theme,
                            l,
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              _buildChip(gallery.type, colorScheme, theme),
                              if (gallery.language != null) ...[
                                const SizedBox(width: 6),
                                _buildChip(
                                  gallery.language!,
                                  colorScheme,
                                  theme,
                                ),
                              ],
                              const Spacer(),
                              Text(
                                '${gallery.pageCount}P',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    List<String> list,
    ColorScheme colors,
    ThemeData theme,
    L l,
  ) {
    final text = list.isNotEmpty ? list.join(', ') : l.na;
    final isNA = list.isEmpty;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 16,
          child: Center(
            child: Icon(
              icon,
              size: 14,
              color: isNA
                  ? colors.onSurfaceVariant.withValues(alpha: 0.4)
                  : colors.onSurfaceVariant.withValues(alpha: 0.8),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isNA
                  ? colors.onSurfaceVariant.withValues(alpha: 0.5)
                  : colors.onSurface,
              fontSize: 12,
              fontWeight: isNA ? FontWeight.normal : FontWeight.w500,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChip(String label, ColorScheme colorScheme, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surfaceContainerHighest
            : colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
        border: isDark
            ? Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              )
            : null,
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: isDark
              ? colorScheme.onSurface
              : colorScheme.onSecondaryContainer,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tag Chip (Interactive)
// ─────────────────────────────────────────────────────────────────────────────
class TagChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color? color;

  const TagChip({super.key, required this.label, this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l = L.of(context);

    final tag = TagInfo.parse(label);

    return ListenableBuilder(
      listenable: AppState.instance.favorites,
      builder: (context, _) {
        final isFav = AppState.instance.favorites.value.isFavorite(
          tag.type,
          tag.value,
        );

        Color? bgColor = color;
        Color fgColor = colorScheme.onSurfaceVariant;
        IconData icon = TagUtils.iconFor(tag.type);

        if (tag.type == 'female' || tag.type == 'male') {
          bgColor = TagUtils.backgroundFor(tag.type, colorScheme);
          fgColor = TagUtils.colorFor(tag.type, colorScheme);
        }

        if (isFav) {
          bgColor = colorScheme.primaryContainer;
          fgColor = colorScheme.onPrimaryContainer;
          icon = Icons.favorite_rounded;
        } else {
          bgColor ??= colorScheme.surfaceContainerHigh;
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              onLongPress: () {
                AppState.instance.toggleFavorite(tag.type, tag.value);
                HapticFeedback.lightImpact();
                AppNotification.show(
                  context,
                  isFav ? l.removedFromFav : l.addedToFav,
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: fgColor),
                    const SizedBox(width: 6),
                    Text(
                      tag.displayLabel,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: fgColor,
                        fontWeight: isFav ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
