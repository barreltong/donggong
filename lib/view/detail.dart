import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/hitomi.dart';
import '../core/app_state.dart';
import '../core/i18n.dart';
import 'app_notification.dart';
import 'widgets.dart';

class DetailBottomSheet extends StatefulWidget {
  final int galleryId;
  const DetailBottomSheet({super.key, required this.galleryId});

  @override
  State<DetailBottomSheet> createState() => _DetailBottomSheetState();
}

class _DetailBottomSheetState extends State<DetailBottomSheet> {
  late Future<Gallery> _galleryFuture;

  @override
  void initState() {
    super.initState();
    _galleryFuture = HitomiManager.instance.getDetail(widget.galleryId);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);
    
    return FutureBuilder<Gallery>(
      future: _galleryFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 250,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.id == 0) {
          return Container(
            height: 200,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Center(child: Text(l.galleryFailedLoad)),
          );
        }

        final gallery = snapshot.data!;
        
        return DraggableScrollableSheet(
          initialChildSize: 0.8, // Default to 80%
          minChildSize: 0.4,     // Allow dragging down to 40%
          maxChildSize: 0.9,     // Allow expansion to 90%
          expand: false,         // Don't expand to fill screen initially
          snap: true,            // Snap to sizes for better UX
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    // Handle Bar - Standardized visual for dragging
                    Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: ListView(
                        controller: scrollController, // Hook into the DraggableScrollableSheet controller
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        children: [
                          _buildHeader(gallery, l),
                          const SizedBox(height: 24),
                          _buildActions(gallery, l),
                          const SizedBox(height: 24),
                          const Divider(height: 1),
                          const SizedBox(height: 20),
                          _buildMetadata(gallery, l),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(Gallery gallery, L l) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: HitomiImage(url: gallery.thumbnail, fit: BoxFit.cover),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                gallery.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                '${gallery.pageCount} ${l.pages} • ${gallery.type.toUpperCase()}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActions(Gallery gallery, L l) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () {
              Navigator.pop(context); 
              Navigator.pushNamed(
                context,
                '/reader',
                arguments: {'id': gallery.id},
              );
              AppState.instance.addToHistory(gallery);
            },
            icon: const Icon(Icons.menu_book_rounded),
            label: Text(l.read),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ListenableBuilder(
          listenable: AppState.instance.favorites,
          builder: (context, _) {
            final isFav = AppState.instance.favorites.value.isFavorite('gallery', gallery.id);
            return IconButton.filledTonal(
              onPressed: () => AppState.instance.toggleFavorite('gallery', gallery.id.toString(), gallery: gallery),
              icon: Icon(
                isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isFav ? Colors.red : null,
              ),
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMetadata(Gallery gallery, L l) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Gallery Info Sector (ID & Language) - Re-introduced column style for clarity
        _buildSectionHeader(l.galleryInfo),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: gallery.id.toString()));
                    HapticFeedback.mediumImpact(); // Vibration effect
                    AppNotification.show(context, l.galleryIdCopied);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    children: [
                      Icon(Icons.fingerprint_rounded, size: 20, color: colorScheme.onSurfaceVariant),
                      const SizedBox(height: 6),
                      Text(
                        'ID: ${gallery.id}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (gallery.language != null) ...[
                Container(width: 1, height: 40, color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                Expanded(
                  child: Column(
                    children: [
                      Icon(Icons.translate_rounded, size: 20, color: colorScheme.onSurfaceVariant),
                      const SizedBox(height: 6),
                      Text(
                        gallery.language!.toUpperCase(),
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 32),
        
        _buildTagSection(l.artist, gallery.artists.map((a) => 'artist:$a').toList(), l),
        _buildTagSection(l.group, gallery.groups.map((g) => 'group:$g').toList(), l),
        _buildTagSection(l.gallerySeries, gallery.parodys, l),
        _buildTagSection(l.galleryCharacters, gallery.characters, l),
        _buildTagSection(l.galleryTags, gallery.tags, l),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildTagSection(String title, List<String> tags, L l) {
    if (tags.isEmpty && title != l.galleryInfo) return const SizedBox.shrink(); 
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(title),
          const SizedBox(height: 10),
          if (tags.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map((tag) => TagChip(label: tag)).toList(),
            ),
        ],
      ),
    );
  }
}
