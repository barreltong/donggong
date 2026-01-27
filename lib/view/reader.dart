import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/hitomi.dart';
import '../core/app_state.dart';
import '../core/i18n.dart';
import 'widgets.dart';
import 'detail.dart'; // For bottom sheet info

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

  // Controllers
  final PageController _pageController = PageController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _galleryFuture = HitomiManager.instance.getReaderData(widget.galleryId).then((gallery) {
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
    final progress = _scrollController.offset / _scrollController.position.maxScrollExtent;
    final page = (progress * (_totalPages - 1)).round();
    if (page != _currentPageNotifier.value) {
      _currentPageNotifier.value = page;
    }
  }

  void _onPageChanged(int index) {
    _currentPageNotifier.value = index;
  }

  void _jumpToPage(int page) {
    final mode = AppState.instance.readerMode.value;
    if (mode == 'webtoon') {
      if (_scrollController.hasClients) {
        final offset = (page / (_totalPages - 1)) * _scrollController.position.maxScrollExtent;
        _scrollController.jumpTo(offset);
      }
    } else {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(page);
      }
    }
    _currentPageNotifier.value = page;
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
          decoration: InputDecoration(
            hintText: l.pageJumpHint(_totalPages),
          ),
          onSubmitted: (val) {
            final page = int.tryParse(val);
            if (page != null && page >= 1 && page <= _totalPages) {
              Navigator.pop(context, page);
            }
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
          TextButton(
            onPressed: () {
              final page = int.tryParse(controller.text);
              if (page != null && page >= 1 && page <= _totalPages) {
                Navigator.pop(context, page);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l.pageJumpInvalid), duration: const Duration(seconds: 1)),
                );
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (jumpPage != null) {
      _jumpToPage(jumpPage - 1);
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
          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.images.isEmpty) {
            return Center(child: Text(l.galleryFailedLoad, style: const TextStyle(color: Colors.white)));
          }

          final gallery = snapshot.data!;
          _totalPages = gallery.images.length;

          return Stack(
            children: [
              GestureDetector(
                onTap: () => setState(() => _showControls = !_showControls),
                child: ListenableBuilder(
                  listenable: AppState.instance.readerMode,
                  builder: (context, _) {
                    final mode = AppState.instance.readerMode.value;
                    if (mode == 'webtoon') {
                      return ListView.builder(
                        controller: _scrollController,
                        itemCount: gallery.images.length,
                        cacheExtent: 2000,
                        itemBuilder: (context, index) {
                          return HitomiImage(
                            url: gallery.images[index].url,
                            fit: BoxFit.contain,
                            width: MediaQuery.of(context).size.width,
                            height: (gallery.images[index].height / gallery.images[index].width) * 
                                MediaQuery.of(context).size.width,
                          );
                        },
                      );
                    } else {
                      return PageView.builder(
                        controller: _pageController,
                        scrollDirection: mode == 'horizontalPage' ? Axis.horizontal : Axis.vertical,
                        itemCount: gallery.images.length,
                        onPageChanged: _onPageChanged,
                        itemBuilder: (context, index) {
                          return InteractiveViewer(
                            minScale: 1.0,
                            maxScale: 4.0,
                            child: Center(
                              child: HitomiImage(
                                url: gallery.images[index].url,
                                fit: BoxFit.contain,
                              ),
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
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Reader Mode Toggle
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.settings_display, color: Colors.white),
                          onSelected: (val) => AppState.instance.updateSetting('readerMode', val),
                          itemBuilder: (context) => [
                            PopupMenuItem(value: 'verticalPage', child: Text(l.verticalPage)),
                            PopupMenuItem(value: 'horizontalPage', child: Text(l.horizontalPage)),
                            PopupMenuItem(value: 'webtoon', child: Text(l.webtoon)),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.info_outline, color: Colors.white),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => DetailBottomSheet(galleryId: gallery.id),
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
                    child: ValueListenableBuilder<int>(
                      valueListenable: _currentPageNotifier,
                      builder: (context, currentPage, _) {
                        return Row(
                          children: [
                            InkWell(
                              onTap: _showPageJumpDialog,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: Text(
                                  '${currentPage + 1}',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Slider(
                                value: currentPage.toDouble().clamp(0, (_totalPages - 1).toDouble()),
                                min: 0,
                                max: (_totalPages > 1) ? (_totalPages - 1).toDouble() : 1,
                                onChanged: (value) => _jumpToPage(value.round()),
                              ),
                            ),
                            InkWell(
                              onTap: _showPageJumpDialog,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: Text(
                                  '$_totalPages',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
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
