import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/hitomi.dart';
import '../core/app_state.dart';
import '../core/i18n.dart';
import '../network/http.dart';
import 'app_notification.dart';
import 'widgets.dart';
import 'detail.dart'; // For bottom sheet info

class _ReaderSpread {
  final int? leftIndex;
  final int? rightIndex;

  const _ReaderSpread({this.leftIndex, this.rightIndex});
}

class _ReaderViewportPlan {
  final String mode;
  final int totalPages;
  final String doublePageOrder;

  const _ReaderViewportPlan({
    required this.mode,
    required this.totalPages,
    required this.doublePageOrder,
  });

  int get viewportCount {
    return mode == 'doublePage' ? ((totalPages + 1) ~/ 2) : totalPages;
  }

  int pageToViewportIndex(int page) {
    return mode == 'doublePage' ? page ~/ 2 : page;
  }

  int viewportIndexToPage(int viewportIndex) {
    return mode == 'doublePage' ? viewportIndex * 2 : viewportIndex;
  }

  _ReaderSpread spreadAt(int spreadIndex) {
    final baseIndex = spreadIndex * 2;
    final isJapanese = doublePageOrder == 'japanese';
    final leftIndex = isJapanese ? baseIndex + 1 : baseIndex;
    final rightIndex = isJapanese ? baseIndex : baseIndex + 1;
    return _ReaderSpread(
      leftIndex: leftIndex < totalPages ? leftIndex : null,
      rightIndex: rightIndex < totalPages ? rightIndex : null,
    );
  }

  String currentPageLabel(int currentPage) {
    if (mode != 'doublePage') return '${currentPage + 1}';
    final spread = spreadAt(currentPage ~/ 2);
    final labels = <String>[
      if (spread.leftIndex != null) '${spread.leftIndex! + 1}',
      if (spread.rightIndex != null) '${spread.rightIndex! + 1}',
    ];
    return labels.join('-');
  }
}

class ReaderScreen extends StatefulWidget {
  final int galleryId;
  const ReaderScreen({super.key, required this.galleryId});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late Future<Gallery> _galleryFuture;
  bool _showControls = true;
  final ValueNotifier<int> _currentPageNotifier = ValueNotifier(0);
  int _totalPages = 0;
  final Set<int> _preloadedPages = <int>{};
  String? _lastReaderMode;

  // Controllers
  final PageController _pageController = PageController();
  final ScrollController _scrollController = ScrollController();

  _ReaderViewportPlan get _viewportPlan => _ReaderViewportPlan(
    mode: AppState.instance.readerMode.value,
    totalPages: _totalPages,
    doublePageOrder: AppState.instance.doublePageOrder.value,
  );

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _galleryFuture = HitomiManager.instance
        .getReaderData(widget.galleryId)
        .then((gallery) {
          if (!gallery.isError && gallery.images.isNotEmpty) {
            AppState.instance.addToHistory(gallery);
          }
          return gallery;
        });
    _scrollController.addListener(_onWebtoonScroll);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pageController.dispose();
    _scrollController.dispose();
    _currentPageNotifier.dispose();
    super.dispose();
  }

  void _onWebtoonScroll() {
    if (!_scrollController.hasClients || _totalPages == 0) return;
    final progress =
        _scrollController.offset / _scrollController.position.maxScrollExtent;
    final page = (progress * (_totalPages - 1)).round();
    if (page != _currentPageNotifier.value) {
      _updateCurrentPage(page);
      _galleryFuture.then((gallery) {
        if (!mounted) return;
        _preloadUpcomingImages(gallery, page);
      });
    }
  }

  void _onPageChanged(Gallery gallery, int index) {
    final page = _viewportPlan.viewportIndexToPage(index);
    _updateCurrentPage(page);
    _preloadUpcomingImages(gallery, page);
  }

  void _updateCurrentPage(int page) {
    _currentPageNotifier.value = page;
  }

  void _preloadUpcomingImages(Gallery gallery, int currentIndex) {
    if (!mounted || gallery.images.isEmpty) return;

    final lastIndex = gallery.images.length - 1;
    final endIndex = (currentIndex + 3).clamp(0, lastIndex);

    for (int index = currentIndex; index <= endIndex; index++) {
      if (!_preloadedPages.add(index)) continue;
      _precacheReaderImage(gallery.images[index].hash);
    }
  }

  Future<void> _precacheReaderImage(String hash) async {
    try {
      final url = await HitomiManager.instance.resolveImageUrl(hash);
      if (!mounted) return;

      await precacheImage(
        CachedNetworkImageProvider(url, headers: HttpClient.defaultHeaders),
        context,
      );
    } catch (_) {}
  }

  void _ensureInitialPreload(Gallery gallery) {
    if (_preloadedPages.isNotEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _preloadUpcomingImages(gallery, _currentPageNotifier.value);
    });
  }

  void _jumpToPage(Gallery gallery, int page) {
    final plan = _viewportPlan;
    if (plan.mode == 'webtoon') {
      if (_scrollController.hasClients) {
        if (_totalPages <= 1) {
          _scrollController.jumpTo(0);
        } else {
          final offset =
              (page / (_totalPages - 1)) *
              _scrollController.position.maxScrollExtent;
          _scrollController.jumpTo(offset);
        }
      }
    } else {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(plan.pageToViewportIndex(page));
      }
    }
    _updateCurrentPage(page);
    _preloadUpcomingImages(gallery, page);
  }

  double _sliderValue(int currentPage) {
    return _viewportPlan.pageToViewportIndex(currentPage).toDouble();
  }

  double _sliderMax() {
    final max = _viewportPlan.viewportCount - 1;
    return max > 0 ? max.toDouble() : 1;
  }

  void _syncViewportForMode(String mode) {
    if (_lastReaderMode == mode) return;
    _lastReaderMode = mode;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentPage = _currentPageNotifier.value;
      if (mode == 'webtoon') return;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(
          _viewportPlan.pageToViewportIndex(currentPage),
        );
      }
    });
  }

  Widget _buildReaderPage(
    GalleryImage image, {
    double? width,
    double? height,
    Alignment alignment = Alignment.center,
  }) {
    return HitomiImage(
      imageHash: image.hash,
      url: image.url,
      fit: BoxFit.contain,
      alignment: alignment,
      width: width,
      height: height,
      showLoadingPlaceholder: false,
      showErrorIndicator: false,
    );
  }

  Widget _buildDoublePageSpread(Gallery gallery, int spreadIndex) {
    final spread = _viewportPlan.spreadAt(spreadIndex);
    final leftPage = spread.leftIndex != null
        ? gallery.images[spread.leftIndex!]
        : null;
    final rightPage = spread.rightIndex != null
        ? gallery.images[spread.rightIndex!]
        : null;

    return InteractiveViewer(
      minScale: 1.0,
      maxScale: 4.0,
      child: Row(
        children: [
          Expanded(
            child: ClipRect(
              child: SizedBox.expand(
                child: leftPage != null
                    ? _buildReaderPage(
                        leftPage,
                        width: double.infinity,
                        height: double.infinity,
                        alignment: Alignment.centerRight,
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
          Expanded(
            child: ClipRect(
              child: SizedBox.expand(
                child: rightPage != null
                    ? _buildReaderPage(
                        rightPage,
                        width: double.infinity,
                        height: double.infinity,
                        alignment: Alignment.centerLeft,
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPageJumpDialog() async {
    final l = L.of(context);
    if (_totalPages <= 1) return;

    final controller = TextEditingController();
    final jumpPage = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.pageJumpTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: l.pageJumpHint(_totalPages)),
          onSubmitted: (val) {
            final page = int.tryParse(val);
            if (page != null && page >= 1 && page <= _totalPages) {
              Navigator.pop(context, page);
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
              final page = int.tryParse(controller.text);
              if (page != null && page >= 1 && page <= _totalPages) {
                Navigator.pop(context, page);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l.pageJumpInvalid),
                    duration: const Duration(seconds: 1),
                  ),
                );
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (jumpPage != null) {
      final gallery = await _galleryFuture;
      if (!mounted) return;
      _jumpToPage(gallery, jumpPage - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<Gallery>(
        future: _galleryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data!.images.isEmpty) {
            return Center(
              child: Text(
                l.galleryFailedLoad,
                style: const TextStyle(color: Colors.white),
              ),
            );
          }

          final gallery = snapshot.data!;
          _totalPages = gallery.images.length;
          _ensureInitialPreload(gallery);

          return Stack(
            children: [
              GestureDetector(
                onTap: () => setState(() => _showControls = !_showControls),
                child: ListenableBuilder(
                  listenable: Listenable.merge([
                    AppState.instance.readerMode,
                    AppState.instance.doublePageOrder,
                    AppState.instance.pageTurnDirection,
                  ]),
                  builder: (context, _) {
                    final mode = AppState.instance.readerMode.value;
                    final isHorizontalPaging =
                        mode == 'horizontalPage' || mode == 'doublePage';
                    _syncViewportForMode(mode);
                    if (mode == 'webtoon') {
                      return ListView.builder(
                        controller: _scrollController,
                        itemCount: gallery.images.length,
                        cacheExtent: 2000,
                        itemBuilder: (context, index) {
                          return _buildReaderPage(
                            gallery.images[index],
                            width: MediaQuery.of(context).size.width,
                            height:
                                (gallery.images[index].height /
                                    gallery.images[index].width) *
                                MediaQuery.of(context).size.width,
                          );
                        },
                      );
                    } else {
                      return PageView.builder(
                        controller: _pageController,
                        reverse:
                            isHorizontalPaging &&
                            AppState.instance.pageTurnDirection.value ==
                                'right',
                        scrollDirection: mode == 'verticalPage'
                            ? Axis.vertical
                            : Axis.horizontal,
                        itemCount: _viewportPlan.viewportCount,
                        onPageChanged: (index) =>
                            _onPageChanged(gallery, index),
                        itemBuilder: (context, index) {
                          if (mode == 'doublePage') {
                            return _buildDoublePageSpread(gallery, index);
                          }

                          return InteractiveViewer(
                            minScale: 1.0,
                            maxScale: 4.0,
                            child: Center(
                              child: _buildReaderPage(gallery.images[index]),
                            ),
                          );
                        },
                      );
                    }
                  },
                ),
              ),

              // Top Bar
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                top: _showControls ? 0 : -80,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.8),
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      children: [
                        const BackButton(color: Colors.white),
                        Expanded(
                          child: Text(
                            gallery.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Reader Mode Toggle
                        PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.settings_display,
                            color: Colors.white,
                          ),
                          onSelected: (val) => AppState.instance.updateSetting(
                            'readerMode',
                            val,
                          ),
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'verticalPage',
                              child: Text(l.verticalPage),
                            ),
                            PopupMenuItem(
                              value: 'horizontalPage',
                              child: Text(l.horizontalPage),
                            ),
                            PopupMenuItem(
                              value: 'doublePage',
                              child: Text(l.doublePage),
                            ),
                            PopupMenuItem(
                              value: 'webtoon',
                              child: Text(l.webtoon),
                            ),
                          ],
                        ),
                        ListenableBuilder(
                          listenable: Listenable.merge([
                            AppState.instance.readerMode,
                            AppState.instance.doublePageOrder,
                          ]),
                          builder: (context, _) {
                            if (AppState.instance.readerMode.value !=
                                'doublePage') {
                              return const SizedBox.shrink();
                            }

                            return PopupMenuButton<String>(
                              icon: const Icon(
                                Icons.chrome_reader_mode_rounded,
                                color: Colors.white,
                              ),
                              onSelected: (val) => AppState.instance
                                  .updateSetting('doublePageOrder', val),
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'japanese',
                                  child: Text(l.doublePageJapanese),
                                ),
                                PopupMenuItem(
                                  value: 'international',
                                  child: Text(l.doublePageInternational),
                                ),
                              ],
                            );
                          },
                        ),
                        ListenableBuilder(
                          listenable: Listenable.merge([
                            AppState.instance.readerMode,
                            AppState.instance.pageTurnDirection,
                          ]),
                          builder: (context, _) {
                            if (AppState.instance.readerMode.value ==
                                'webtoon') {
                              return const SizedBox.shrink();
                            }

                            return PopupMenuButton<String>(
                              icon: const Icon(
                                Icons.swipe_rounded,
                                color: Colors.white,
                              ),
                              onSelected: (val) => AppState.instance
                                  .updateSetting('pageTurnDirection', val),
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'left',
                                  child: Text(l.pageTurnLeft),
                                ),
                                PopupMenuItem(
                                  value: 'right',
                                  child: Text(l.pageTurnRight),
                                ),
                              ],
                            );
                          },
                        ),
                        ListenableBuilder(
                          listenable: AppState.instance.favorites,
                          builder: (context, _) {
                            final isFav = AppState.instance.favorites.value
                                .isFavorite('gallery', gallery.id);

                            return IconButton(
                              icon: Icon(
                                isFav
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: isFav ? Colors.redAccent : Colors.white,
                              ),
                              onPressed: () async {
                                await AppState.instance.toggleFavorite(
                                  'gallery',
                                  gallery.id.toString(),
                                  gallery: gallery,
                                );
                                if (!mounted) return;
                                AppNotification.show(
                                  this.context,
                                  isFav ? l.removedFromFav : l.addedToFav,
                                );
                              },
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.info_outline,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => DetailBottomSheet(
                                galleryId: gallery.id,
                                onSearchTag: (query) {
                                  AppState.instance.pendingSearch.value = query;
                                  Navigator.of(
                                    context,
                                  ).popUntil((route) => route.isFirst);
                                },
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom Bar
              AnimatedPositioned(
                duration: const Duration(milliseconds: 200),
                bottom: _showControls ? 0 : -100,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.8),
                  padding: const EdgeInsets.all(16),
                  child: SafeArea(
                    top: false,
                    child: ListenableBuilder(
                      listenable: Listenable.merge([
                        AppState.instance.readerMode,
                        AppState.instance.doublePageOrder,
                      ]),
                      builder: (context, _) {
                        return ValueListenableBuilder<int>(
                          valueListenable: _currentPageNotifier,
                          builder: (context, currentPage, _) {
                            return Row(
                              children: [
                                InkWell(
                                  onTap: _showPageJumpDialog,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    child: Text(
                                      _viewportPlan.currentPageLabel(
                                        currentPage,
                                      ),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Slider(
                                    value: _sliderValue(
                                      currentPage,
                                    ).clamp(0, _sliderMax()),
                                    min: 0,
                                    max: _sliderMax(),
                                    onChanged: (value) => _jumpToPage(
                                      gallery,
                                      _viewportPlan.viewportIndexToPage(
                                        value.round(),
                                      ),
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: _showPageJumpDialog,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    child: Text(
                                      '$_totalPages',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
