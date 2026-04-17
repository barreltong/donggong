import 'package:flutter/material.dart';
import '../core/hitomi.dart';
import '../core/app_state.dart';
import '../core/i18n.dart';
import '../core/tag_utils.dart';
import 'widgets.dart';
import 'search_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<Gallery> _galleries = [];
  int _page = 1;
  int _totalCount = 0;
  bool _isLoading = false;
  String _query = '';
  bool _showFab = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(_onScroll);
    AppState.instance.defaultLanguage.addListener(_onLanguageChanged);
    AppState.instance.listingMode.addListener(_onListingModeChanged);
    AppState.instance.pendingSearch.addListener(_onPendingSearch);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    AppState.instance.defaultLanguage.removeListener(_onLanguageChanged);
    AppState.instance.listingMode.removeListener(_onListingModeChanged);
    AppState.instance.pendingSearch.removeListener(_onPendingSearch);
    super.dispose();
  }

  void _onLanguageChanged() {
    if (mounted) {
      _loadData(refresh: true, targetPage: 1);
    }
  }

  void _onListingModeChanged() {
    if (mounted) {
      _loadData(refresh: true, targetPage: 1);
    }
  }

  void _onPendingSearch() {
    final query = AppState.instance.pendingSearch.value;
    if (query == null || !mounted) return;
    AppState.instance.pendingSearch.value = null;
    _onSearchSubmitted(query);
  }

  void _onScroll() {
    // Show/Hide FAB
    if (_scrollController.hasClients) {
      if (_scrollController.offset > 300 && !_showFab) {
        setState(() => _showFab = true);
      } else if (_scrollController.offset <= 300 && _showFab) {
        setState(() => _showFab = false);
      }
    }

    if (AppState.instance.listingMode.value == 'pagination') return;

    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 400) {
      _loadData();
    }
  }

  Future<void> _loadData({bool refresh = false, int? targetPage}) async {
    if (_isLoading) return;

    final pageToLoad = targetPage ?? _page;

    setState(() => _isLoading = true);

    try {
      final defaultLang = AppState.instance.defaultLanguage.value;
      final result = _query.isEmpty
          ? await HitomiManager.instance.getList(
              page: pageToLoad,
              lang: defaultLang,
            )
          : await HitomiManager.instance.search(
              _query,
              page: pageToLoad,
              defaultLang: defaultLang,
            );

      if (mounted) {
        setState(() {
          if (refresh || AppState.instance.listingMode.value == 'pagination') {
            _galleries = result.$1;
          } else {
            _galleries.addAll(result.$1);
          }

          _totalCount = result.$2;
          _isLoading = false;
          _page = pageToLoad + 1;
        });

        if (targetPage != null && _scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _onSearchSubmitted(String query) {
    final normalizedQuery = TagUtils.normalizeQuery(query);
    setState(() {
      _query = normalizedQuery;
      _page = 1;
    });
    if (normalizedQuery.isNotEmpty) {
      AppState.instance.addRecentSearch(normalizedQuery);
    }
    _loadData(refresh: true, targetPage: 1);
  }

  Future<void> _showPageJumpDialog() async {
    final l = L.of(context);
    final totalPages = (_totalCount / HitomiConstants.pageSize).ceil();
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
            final page = int.tryParse(val);
            if (page != null && page >= 1 && page <= totalPages) {
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
              if (page != null && page >= 1 && page <= totalPages) {
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
            child: Text('OK'),
          ),
        ],
      ),
    );

    if (jumpPage != null) {
      _loadData(refresh: true, targetPage: jumpPage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          toolbarHeight: 80, // Increased for search bar breathing room
          titleSpacing: 0,
          title: HomeSearchBar(
            query: _query,
            onSubmitted: _onSearchSubmitted,
            onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          automaticallyImplyLeading: false,
        ),
        drawer: const HomeDrawer(),
        body: ListenableBuilder(
          listenable: Listenable.merge([
            AppState.instance.listingMode,
            AppState.instance.cardViewMode,
          ]),
          builder: (context, _) {
            final isPagination =
                AppState.instance.listingMode.value == 'pagination';

            // 페이지네이션 모드에서만 블로킹 오버레이 적용
            return LoadingOverlay(
              isLoading: isPagination && _isLoading,
              child: _buildBody(l, isPagination),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(L l, bool isPagination) {
    final isDetailed = AppState.instance.cardViewMode.value == 'detailed';

    return Stack(
      children: [
        Column(
          children: [
            if (_totalCount > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                color: Theme.of(context).colorScheme.surface,
                child: Row(
                  children: [
                    Text(
                      l.foundResults(_totalCount),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    ),
                    const Spacer(),
                    if (_isLoading && !isPagination)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  setState(() {
                    _galleries.clear();
                    _totalCount = 0;
                  });
                  await _loadData(refresh: true, targetPage: 1);
                },
                child: _galleries.isEmpty && !_isLoading
                    ? _buildEmptyState(l)
                    : GalleryGrid(
                        galleries: _galleries,
                        isLoading: _isLoading && !isPagination,
                        scrollController: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        onSearchTag: (query) => _onSearchSubmitted(query),
                      ),
              ),
            ),
            if (isPagination) _buildPaginationBar(),
          ],
        ),

        Positioned(
          right: 16,
          bottom: isPagination ? 120 : 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small(
                heroTag: 'viewMode',
                elevation: 4,
                onPressed: () {
                  final current = AppState.instance.cardViewMode.value;
                  AppState.instance.updateSetting(
                    'cardViewMode',
                    current == 'thumbnail' ? 'detailed' : 'thumbnail',
                  );
                },
                child: Icon(
                  isDetailed
                      ? Icons.grid_view_rounded
                      : Icons.view_list_rounded,
                ),
              ),
              if (_showFab) ...[
                const SizedBox(height: 12),
                FloatingActionButton.small(
                  heroTag: 'scrollTop',
                  elevation: 4,
                  onPressed: () {
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                    );
                  },
                  child: const Icon(Icons.arrow_upward_rounded),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaginationBar() {
    final theme = Theme.of(context);
    final currentPage = _page - 1;
    final totalPages = (_totalCount / HitomiConstants.pageSize).ceil();

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
              onPressed: currentPage > 1
                  ? () => _loadData(refresh: true, targetPage: 1)
                  : null,
            ),
            IconButton.filledTonal(
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: currentPage > 1
                  ? () => _loadData(refresh: true, targetPage: currentPage - 1)
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
                  '$currentPage / $totalPages',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
            ),
            IconButton.filledTonal(
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: currentPage < totalPages
                  ? () => _loadData(refresh: true, targetPage: currentPage + 1)
                  : null,
            ),
            IconButton.filledTonal(
              icon: const Icon(Icons.last_page_rounded),
              onPressed: currentPage < totalPages
                  ? () => _loadData(refresh: true, targetPage: totalPages)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(L l) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(l.noResults, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

class HomeDrawer extends StatelessWidget {
  const HomeDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Drawer(
      backgroundColor: colorScheme.surface,
      elevation: 0, // Flat design for modern look
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 80, 24, 32),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.auto_stories_rounded,
                    color: colorScheme.surface,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  l.appTitle,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l.appSubtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildDrawerItem(
                  context,
                  icon: Icons.home_rounded,
                  label: l.home,
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(height: 4),
                _buildDrawerItem(
                  context,
                  icon: Icons.favorite_rounded,
                  label: l.favorites,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/favorites');
                  },
                ),
                const SizedBox(height: 4),
                _buildDrawerItem(
                  context,
                  icon: Icons.history_rounded,
                  label: l.history,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/history');
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Divider(
                    thickness: 1,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.1),
                  ),
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.settings_rounded,
                  label: l.settings,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/settings');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: colorScheme.onSurfaceVariant, size: 22),
      title: Text(
        label,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      onTap: onTap,
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
