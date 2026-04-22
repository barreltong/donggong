import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/hitomi.dart';
import '../core/i18n.dart';
import '../core/tag_utils.dart';
import 'app_notification.dart';
import 'reader.dart';

class HomeSearchBar extends StatefulWidget {
  final bool allowDirectId;
  final String query;
  final Function(String) onSubmitted;
  final VoidCallback onMenuPressed;
  final ValueChanged<bool>? onFocusChanged;

  const HomeSearchBar({
    super.key,
    this.allowDirectId = true,
    this.query = '',
    required this.onSubmitted,
    required this.onMenuPressed,
    this.onFocusChanged,
  });

  @override
  State<HomeSearchBar> createState() => _HomeSearchBarState();
}

class _HomeSearchBarState extends State<HomeSearchBar>
    with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _overlayContentKey = GlobalKey();

  OverlayEntry? _overlayEntry;
  List<TagSuggestion> _suggestions = [];
  int _suggestionRequestId = 0;
  double _lastKeyboardInset = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller.text = widget.query;
    _focusNode.addListener(() {
      widget.onFocusChanged?.call(_focusNode.hasFocus);
      if (_focusNode.hasFocus) {
        _updateOverlay(); // Show overlay immediately on focus
        _onTextChanged(_controller.text);
      } else {
        _suggestionRequestId++;
        _hideOverlay();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideOverlay();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final keyboardInset = WidgetsBinding
        .instance
        .platformDispatcher
        .views
        .first
        .viewInsets
        .bottom;
    final keyboardWasVisible = _lastKeyboardInset > 0;
    _lastKeyboardInset = keyboardInset;

    if (keyboardWasVisible && keyboardInset == 0 && _overlayEntry != null) {
      _suggestionRequestId++;
      _hideOverlay();
      if (_focusNode.hasFocus) {
        _focusNode.unfocus();
      }
    }
  }

  @override
  void didUpdateWidget(covariant HomeSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != oldWidget.query && widget.query != _controller.text) {
      _controller.text = widget.query;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: widget.query.length),
      );
    }
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _dismissOverlayAndUnfocus() {
    _suggestionRequestId++;
    _hideOverlay();
    if (_focusNode.hasFocus) {
      _focusNode.unfocus();
    }
  }

  bool _containsGlobalPoint(GlobalKey key, Offset position) {
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) return false;

    final rect = renderObject.localToGlobal(Offset.zero) & renderObject.size;
    return rect.contains(position);
  }

  void _showOverlay() {
    _hideOverlay();
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _updateOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
    } else {
      _showOverlay();
    }
  }

  Future<void> _onTextChanged(String text) async {
    final requestId = ++_suggestionRequestId;

    if (text.isEmpty || text.endsWith(' ')) {
      // Show recent history
      final recent = AppState.instance.recentSearches.value;
      if (mounted && _focusNode.hasFocus && requestId == _suggestionRequestId) {
        setState(() {
          _suggestions = recent
              .map((e) => TagSuggestion(tag: e, type: 'recent', count: 0))
              .toList();
        });
        _updateOverlay();
      }
      return;
    }

    final lastToken = text.split(' ').last;
    if (lastToken.isEmpty) return;

    try {
      final suggestions = await HitomiManager.instance.getTagSuggestions(
        lastToken,
      );
      if (mounted && _focusNode.hasFocus && requestId == _suggestionRequestId) {
        setState(() => _suggestions = suggestions);
        _updateOverlay();
      }
    } catch (_) {
      if (mounted && _focusNode.hasFocus && requestId == _suggestionRequestId) {
        setState(() => _suggestions = []);
        _hideOverlay(); // Hide if no suggestions and not empty text (to show favs? No, hide)
      }
    }
  }

  void _addTagToQuery(String tag) {
    final currentText = _controller.text;
    final tokens = currentText.split(' ');
    if (tokens.isNotEmpty && !currentText.endsWith(' ')) tokens.removeLast();

    tokens.add(TagUtils.normalizeTagLabel(tag));
    final newQuery = '${tokens.join(' ')} ';

    _controller.text = newQuery;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: newQuery.length),
    );

    _focusNode.requestFocus();
    _onTextChanged(newQuery);
  }

  void _onSubmit(String text) {
    final normalizedText = TagUtils.normalizeQuery(text);
    _hideOverlay();
    _focusNode.unfocus();

    if (widget.allowDirectId && RegExp(r'^\d+$').hasMatch(normalizedText)) {
      final id = int.tryParse(normalizedText);
      if (id != null) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => ReaderScreen(galleryId: id)),
        );
        return;
      }
    }

    if (_controller.text != normalizedText) {
      _controller.text = normalizedText;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: normalizedText.length),
      );
    }

    widget.onSubmitted(normalizedText);
  }

  Future<void> _deleteFavorite(String type, String value) async {
    final l = L.of(context);
    final displayLabel = TagUtils.displayName(value);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.favDeleteTitle),
        content: Text(l.favDeleteBody('$type:$displayLabel')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AppState.instance.toggleFavorite(type, value);
      if (mounted) {
        AppNotification.show(context, l.removedFromFav);
        setState(() {}); // Rebuild to refresh overlay
        _updateOverlay();
      }
    }
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (event) {
                if (_containsGlobalPoint(_overlayContentKey, event.position)) {
                  return;
                }

                final searchBarRenderObject = this.context.findRenderObject();
                if (searchBarRenderObject is RenderBox) {
                  final searchBarRect =
                      searchBarRenderObject.localToGlobal(Offset.zero) &
                      searchBarRenderObject.size;
                  if (searchBarRect.contains(event.position)) {
                    return;
                  }
                }

                _dismissOverlayAndUnfocus();
              },
            ),
          ),
          Positioned(
            width: size.width - 32,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(16, size.height + 8),
              child: KeyedSubtree(
                key: _overlayContentKey,
                child: Material(
                  elevation: 12,
                  shadowColor: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                  color: colorScheme.surfaceContainer,
                  clipBehavior: Clip.antiAlias,
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    tween: Tween(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, (1.0 - value) * -10),
                          child: child,
                        ),
                      );
                    },
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 450),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListenableBuilder(
                            listenable: AppState.instance.favorites,
                            builder: (context, child) {
                              final favTags = AppState
                                  .instance
                                  .favorites
                                  .value
                                  .allChips
                                  .toList();
                              if (favTags.isEmpty) {
                                return const SizedBox.shrink();
                              }

                              return Container(
                                height: 56,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: colorScheme.outlineVariant
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                ),
                                child: ListView.separated(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  scrollDirection: Axis.horizontal,
                                  itemCount: favTags.length,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (context, index) {
                                    final tagLabel = favTags[index];
                                    final tagInfo = TagInfo.parse(tagLabel);

                                    Color chipColor = colorScheme
                                        .secondaryContainer
                                        .withValues(alpha: 0.5);
                                    Color iconColor =
                                        colorScheme.onSecondaryContainer;
                                    IconData icon = TagUtils.iconFor(
                                      tagInfo.type,
                                    );

                                    if (tagInfo.type == 'female' ||
                                        tagInfo.type == 'male') {
                                      iconColor = TagUtils.colorFor(
                                        tagInfo.type,
                                        colorScheme,
                                      );
                                      chipColor = TagUtils.backgroundFor(
                                        tagInfo.type,
                                        colorScheme,
                                      );
                                    }

                                    return Center(
                                      child: Material(
                                        color: chipColor,
                                        borderRadius: BorderRadius.circular(20),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          onTap: () => _addTagToQuery(tagLabel),
                                          onLongPress: () => _deleteFavorite(
                                            tagInfo.type,
                                            tagInfo.value,
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 8,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  icon,
                                                  size: 14,
                                                  color: iconColor,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  tagInfo.displayLabel,
                                                  style: theme
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        color: iconColor,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                          if (_suggestions.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                AppState.instance.recentSearches.value.isEmpty
                                    ? 'Search tags or IDs'
                                    : 'Recent Searches',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: colorScheme.outline,
                                ),
                              ),
                            )
                          else
                            Flexible(
                              child: ListView.separated(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: _suggestions.length,
                                separatorBuilder: (context, index) => Divider(
                                  height: 1,
                                  thickness: 0.5,
                                  color: colorScheme.outlineVariant.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                                itemBuilder: (context, index) {
                                  final item = _suggestions[index];
                                  return _buildSuggestionTile(
                                    item,
                                    theme,
                                    colorScheme,
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionTile(
    TagSuggestion item,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    IconData icon = item.type == 'recent'
        ? Icons.history_rounded
        : TagUtils.iconFor(item.type);
    Color color = item.type == 'recent'
        ? colorScheme.secondary
        : TagUtils.colorFor(item.type, colorScheme);

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: color),
      ),
      title: Text.rich(
        TextSpan(
          children: [
            if (item.type != 'recent')
              TextSpan(
                text: '${item.type}: ',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            TextSpan(
              text: item.tag,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      trailing: item.count > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${item.count}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.outline,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: () async {
                if (item.type == 'recent') {
                  await AppState.instance.removeRecentSearch(item.tag);
                  _onTextChanged('');
                }
              },
              color: colorScheme.outline,
            ),
      onTap: () {
        if (item.type == 'recent') {
          _onSubmit(item.tag);
        } else {
          _addTagToQuery('${item.type}:${item.tag}');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l = L.of(context);

    return CompositedTransformTarget(
      link: _layerLink,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          16,
          8,
          16,
          12,
        ), // Added bottom padding to let shadow breathe
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.3 : 0.12,
                ),
                blurRadius: 12,
                spreadRadius:
                    0, // Reset spreadRadius to prevent artifacting, rely on padding
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.menu_rounded),
                onPressed: widget.onMenuPressed,
                color: colorScheme.onSurfaceVariant,
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  textAlignVertical: TextAlignVertical
                      .center, // Ensure text is centered vertically
                  decoration: InputDecoration(
                    hintText: l.searchHint,
                    hintStyle: TextStyle(
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.5,
                      ),
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    isCollapsed:
                        true, // Use isCollapsed for better height control
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: colorScheme.onSurface,
                  ),
                  onChanged: (val) {
                    setState(() {});
                    _onTextChanged(val);
                  },
                  onSubmitted: _onSubmit,
                ),
              ),
              if (_controller.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    _controller.clear();
                    _hideOverlay();
                    widget.onSubmitted('');
                  },
                  color: colorScheme.onSurfaceVariant,
                ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
