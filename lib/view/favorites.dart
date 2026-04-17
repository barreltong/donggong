import 'dart:convert';
import 'package:sqflite/sqflite.dart'; // For ConflictAlgorithm
import 'package:flutter/foundation.dart'; // For compute
import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/hitomi.dart';
import '../core/database.dart';
import '../core/i18n.dart';
import 'widgets.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _scrollController = ScrollController();
  List<Gallery> _allFavorites = [];
  List<Gallery> _displayGalleries = [];
  int _page = 1;
  int _totalCount = 0;
  bool _isLoading = false;
  final int _pageSize = HitomiConstants.pageSize;

  @override
  void initState() {
    super.initState();
    _loadAll();
    _scrollController.addListener(_onScroll);
    AppState.instance.listingMode.addListener(_onListingModeChanged);
    AppState.instance.favorites.addListener(_loadAll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    AppState.instance.listingMode.removeListener(_onListingModeChanged);
    AppState.instance.favorites.removeListener(_loadAll);
    super.dispose();
  }

  void _onListingModeChanged() {
    if (mounted) {
      _applyListingMode(targetPage: 1);
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    }
  }

  void _onScroll() {
    if (AppState.instance.listingMode.value == 'pagination') return;
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _loadAll() async {
    if (_isLoading) return; // Prevent duplicate loads
    setState(() => _isLoading = true);

    final favIds = AppState.instance.favorites.value.galleries.toList();
    if (favIds.isEmpty) {
      setState(() {
        _allFavorites = [];
        _displayGalleries = [];
        _totalCount = 0;
        _isLoading = false;
      });
      return;
    }

    // V1 Pattern: Load all cached galleries FIRST, then show UI
    // NO placeholders - only show items that are actually loaded
    final reversedIds = favIds.reversed.toList();

    // 1. Load ALL cached items at once (before showing anything)
    final List<Gallery> allCachedGalleries = [];
    final cachedMaps = await DbManager.getCachedGalleries(favIds);

    // Decode in background
    if (cachedMaps.isNotEmpty) {
      final decoded = await compute(_parseGalleryChunk, cachedMaps);
      allCachedGalleries.addAll(decoded);
    }

    // 2. Build ordered list from cached items only (no placeholders)
    final galleryMap = {for (var g in allCachedGalleries) g.id: g};
    final List<Gallery> builtList = [];
    final List<int> missingIds = [];

    for (final id in reversedIds) {
      if (galleryMap.containsKey(id)) {
        builtList.add(galleryMap[id]!);
      } else {
        missingIds.add(id);
      }
    }

    // 3. Show UI with cached data only (single setState, no flicker)
    if (mounted) {
      setState(() {
        _allFavorites = builtList;
        _totalCount = builtList.length;
        _isLoading = false;
      });
      _applyListingMode(targetPage: _page);
    }

    // 4. Fetch missing items in background (don't block UI)
    if (missingIds.isNotEmpty) {
      _processMissingIds(missingIds, reversedIds);
    }
  }

  // Top-level function for compute
  static List<Gallery> _parseGalleryChunk(List<Map<String, dynamic>> maps) {
    final List<Gallery> result = [];
    for (var map in maps) {
      try {
        final jsonStr = map['json'] as String;
        result.add(Gallery.fromJson(jsonDecode(jsonStr)));
      } catch (_) {}
    }
    return result;
  }

  Future<void> _processMissingIds(
    List<int> missingIds,
    List<int> orderedIds,
  ) async {
    // Fetch in chunks of 10
    const int fetchChunkSize = 10;

    for (var i = 0; i < missingIds.length; i += fetchChunkSize) {
      if (!mounted) return;

      final end = (i + fetchChunkSize < missingIds.length)
          ? i + fetchChunkSize
          : missingIds.length;
      final chunkIds = missingIds.sublist(i, end);

      final fetchFutures = chunkIds.map((id) => _fetchSingleGallerySafe(id));
      final results = await Future.wait(fetchFutures);

      final fetchedGalleries = results
          .where((g) => g != null && !g.isError)
          .cast<Gallery>()
          .toList();

      if (fetchedGalleries.isNotEmpty) {
        // Save to DB
        final batch = DbManager.db.batch();
        for (final gallery in fetchedGalleries) {
          batch.insert('gallery_cache', {
            'id': gallery.id,
            'json': jsonEncode(gallery.toJson()),
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);

        // Insert at correct positions
        if (mounted) {
          setState(() {
            final galleryMap = {for (var g in fetchedGalleries) g.id: g};
            final existingMap = {for (var g in _allFavorites) g.id: g};

            // Rebuild list with correct order including new items
            final List<Gallery> newList = [];
            for (final id in orderedIds) {
              if (galleryMap.containsKey(id)) {
                newList.add(galleryMap[id]!);
              } else if (existingMap.containsKey(id)) {
                newList.add(existingMap[id]!);
              }
              // Skip IDs that we don't have (either not fetched yet or 404'd)
            }

            _allFavorites = newList;
            _totalCount = newList.length;
            _applyListingMode(targetPage: _page);
          });
        }
      }
    }
  }

  Future<Gallery?> _fetchSingleGallerySafe(int id) async {
    try {
      final gallery = await HitomiManager.instance.getDetail(id);
      if (gallery.id != 0) {
        return gallery;
      } else {
        return Gallery.error(id);
      }
    } on GalleryNotFoundException catch (_) {
      if (mounted) {
        AppState.instance.toggleFavorite('gallery', id.toString());
      }
      return null;
    } catch (_) {
      return Gallery.error(id);
    }
  }

  Future<void> _retryLoading(Gallery gallery) async {
    final index = _allFavorites.indexWhere((g) => g.id == gallery.id);
    if (index != -1) {
      setState(() {
        _allFavorites[index] = Gallery.loading(gallery.id);
        _applyListingMode(targetPage: _page);
      });
    }

    try {
      final fetched = await HitomiManager.instance.getDetail(gallery.id);
      if (fetched.id != 0) {
        if (mounted) {
          setState(() {
            _allFavorites[index] = fetched;
            _applyListingMode(targetPage: _page);
          });
          await DbManager.cacheGallery(
            fetched.id,
            jsonEncode(fetched.toJson()),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _allFavorites[index] = Gallery.error(gallery.id);
          _applyListingMode(targetPage: _page);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Retrying ${gallery.id} failed again.')),
        );
      }
    }
  }

  void _applyListingMode({int targetPage = 1, bool append = false}) {
    final mode = AppState.instance.listingMode.value;
    if (mode == 'pagination') {
      final start = (targetPage - 1) * _pageSize;
      final end = (start + _pageSize).clamp(0, _totalCount);
      setState(() {
        _displayGalleries = _allFavorites.sublist(start, end);
        _page = targetPage;
      });
    } else {
      final end = (targetPage * _pageSize).clamp(0, _totalCount);
      setState(() {
        if (append) {
          _displayGalleries = _allFavorites.sublist(0, end);
        } else {
          _displayGalleries = _allFavorites.sublist(0, end);
        }
        _page = targetPage;
      });
    }
  }

  void _loadMore() {
    if (_isLoading || _displayGalleries.length >= _totalCount) return;
    _applyListingMode(targetPage: _page + 1, append: true);
  }

  void _searchTag(String query) {
    AppState.instance.pendingSearch.value = query;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _showPageJumpDialog() async {
    final l = L.of(context);
    final totalPages = (_totalCount / _pageSize).ceil();
    if (totalPages <= 1) return;

    final controller = TextEditingController();
    final jumpPage = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.pageJumpTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: l.pageJumpHint(totalPages)),
          onSubmitted: (val) {
            final p = int.tryParse(val);
            if (p != null && p >= 1 && p <= totalPages) {
              Navigator.pop(context, p);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () {
              final p = int.tryParse(controller.text);
              if (p != null && p >= 1 && p <= totalPages) {
                Navigator.pop(context, p);
              } else {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(l.pageJumpInvalid)));
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (jumpPage != null) {
      _applyListingMode(targetPage: jumpPage);
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l.favorites,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListenableBuilder(
        listenable: AppState.instance.listingMode,
        builder: (context, _) {
          final isPagination =
              AppState.instance.listingMode.value == 'pagination';

          if (_isLoading && _allFavorites.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_allFavorites.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border_rounded,
                    size: 64,
                    color: theme.colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(l.noResults, style: theme.textTheme.titleMedium),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: GalleryGrid(
                  galleries: _displayGalleries,
                  isLoading:
                      !isPagination && _displayGalleries.length < _totalCount,
                  scrollController: _scrollController,
                  onRetry: _retryLoading,
                  onSearchTag: _searchTag,
                ),
              ),
              if (isPagination) _buildPaginationBar(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPaginationBar() {
    final theme = Theme.of(context);
    final totalPages = (_totalCount / _pageSize).ceil();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton.filledTonal(
              icon: const Icon(Icons.first_page_rounded),
              onPressed: _page > 1
                  ? () {
                      _applyListingMode(targetPage: 1);
                      if (_scrollController.hasClients) {
                        _scrollController.jumpTo(0);
                      }
                    }
                  : null,
            ),
            IconButton.filledTonal(
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: _page > 1
                  ? () {
                      _applyListingMode(targetPage: _page - 1);
                      if (_scrollController.hasClients) {
                        _scrollController.jumpTo(0);
                      }
                    }
                  : null,
            ),
            InkWell(
              onTap: _showPageJumpDialog,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_page / $totalPages',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ),
            IconButton.filledTonal(
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: _page < totalPages
                  ? () {
                      _applyListingMode(targetPage: _page + 1);
                      if (_scrollController.hasClients) {
                        _scrollController.jumpTo(0);
                      }
                    }
                  : null,
            ),
            IconButton.filledTonal(
              icon: const Icon(Icons.last_page_rounded),
              onPressed: _page < totalPages
                  ? () {
                      _applyListingMode(targetPage: totalPages);
                      if (_scrollController.hasClients) {
                        _scrollController.jumpTo(0);
                      }
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
