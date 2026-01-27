import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/i18n.dart';
import 'widgets.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.history, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever_rounded),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(l.historyClearTitle),
                  content: Text(l.historyClearBody), 
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.cancel)),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true), 
                      child: Text(l.delete, style: TextStyle(color: theme.colorScheme.error)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await AppState.instance.clearHistory();
              }
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: AppState.instance.history,
        builder: (context, _) {
          final history = AppState.instance.history.value;
          if (history.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_rounded, size: 64, color: theme.colorScheme.outlineVariant),
                  const SizedBox(height: 16),
                  Text(l.noResults, style: theme.textTheme.titleMedium),
                ],
              ),
            );
          }

          return GalleryGrid(
            galleries: history,
            scrollController: _scrollController,
            padding: const EdgeInsets.all(16),
            onDismissed: (gallery) {
              AppState.instance.removeFromHistory(gallery.id);
            },
          );
        },
      ),
    );
  }
}
