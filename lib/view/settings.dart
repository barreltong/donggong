import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import '../core/app_state.dart';
import '../core/database.dart';
import '../core/i18n.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _compactDoublePageOrderLabel(L l, String value) {
    final isKo = l.locale.languageCode == 'ko';
    switch (value) {
      case 'japanese':
        return isKo ? '일본식' : 'Japanese RTL';
      case 'international':
        return isKo ? '국제식' : 'Intl LTR';
      default:
        return value;
    }
  }

  String _compactPageTurnLabel(L l, String value) {
    final isKo = l.locale.languageCode == 'ko';
    switch (value) {
      case 'left':
        return isKo ? '왼쪽' : 'Left';
      case 'right':
        return isKo ? '오른쪽' : 'Right';
      default:
        return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = L.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          l.settings,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        children: [
          _buildSectionHeader(context, l.appearance),
          _buildCard(
            context,
            children: [
              _buildSettingItem(
                context,
                icon: Icons.language_rounded,
                title: l.appLanguage,
                trailing: ListenableBuilder(
                  listenable: AppState.instance.appLanguage,
                  builder: (context, _) {
                    return DropdownButton<String>(
                      value: AppState.instance.appLanguage.value,
                      underline: const SizedBox(),
                      onChanged: (val) {
                        if (val != null) {
                          AppState.instance.updateSetting('appLanguage', val);
                        }
                      },
                      items: [
                        DropdownMenuItem(
                          value: 'en',
                          child: Text(l.langEnglish),
                        ),
                        DropdownMenuItem(
                          value: 'ko',
                          child: Text(l.langKorean),
                        ),
                      ],
                    );
                  },
                ),
              ),
              _buildSettingItem(
                context,
                icon: Icons.brightness_6_rounded,
                title: l.theme,
                trailing: ListenableBuilder(
                  listenable: AppState.instance.themeModeKey,
                  builder: (context, _) {
                    final modeKey = AppState.instance.themeModeKey.value;
                    return DropdownButton<String>(
                      value: modeKey,
                      underline: const SizedBox(),
                      onChanged: (newMode) {
                        if (newMode != null) {
                          AppState.instance.updateSetting(
                            'themeModeKey',
                            newMode,
                          );
                        }
                      },
                      items: [
                        DropdownMenuItem(
                          value: 'system',
                          child: Text(l.themeSystem),
                        ),
                        DropdownMenuItem(
                          value: 'light',
                          child: Text(l.themeLight),
                        ),
                        DropdownMenuItem(
                          value: 'dark',
                          child: Text(l.themeDark),
                        ),
                        DropdownMenuItem(
                          value: 'oled',
                          child: Text(l.themeOled),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),

          _buildSectionHeader(context, l.browsing),
          _buildCard(
            context,
            children: [
              _buildSettingItem(
                context,
                icon: Icons.translate_rounded,
                title: l.defaultLanguage,
                subtitle: l.defaultLanguageDesc,
                trailing: ListenableBuilder(
                  listenable: AppState.instance.defaultLanguage,
                  builder: (context, _) {
                    return DropdownButton<String>(
                      value: AppState.instance.defaultLanguage.value,
                      underline: const SizedBox(),
                      onChanged: (val) {
                        if (val != null) {
                          AppState.instance.updateSetting(
                            'defaultLanguage',
                            val,
                          );
                        }
                      },
                      items: [
                        DropdownMenuItem(value: 'all', child: Text(l.langAll)),
                        DropdownMenuItem(
                          value: 'korean',
                          child: Text(l.langKorean),
                        ),
                        DropdownMenuItem(
                          value: 'english',
                          child: Text(l.langEnglish),
                        ),
                        DropdownMenuItem(
                          value: 'japanese',
                          child: Text(l.langJapanese),
                        ),
                        DropdownMenuItem(
                          value: 'chinese',
                          child: Text(l.langChinese),
                        ),
                      ],
                    );
                  },
                ),
              ),
              _buildSettingItem(
                context,
                icon: Icons.view_quilt_rounded,
                title: l.listingMode,
                trailing: ListenableBuilder(
                  listenable: AppState.instance.listingMode,
                  builder: (context, _) {
                    return DropdownButton<String>(
                      value: AppState.instance.listingMode.value,
                      underline: const SizedBox(),
                      onChanged: (val) {
                        if (val != null) {
                          AppState.instance.updateSetting('listingMode', val);
                        }
                      },
                      items: [
                        DropdownMenuItem(
                          value: 'scroll',
                          child: Text(l.infiniteScroll),
                        ),
                        DropdownMenuItem(
                          value: 'pagination',
                          child: Text(l.pagination),
                        ),
                      ],
                    );
                  },
                ),
              ),
              _buildSettingItem(
                context,
                icon: Icons.grid_view_rounded,
                title: l.cardStyle,
                trailing: ListenableBuilder(
                  listenable: AppState.instance.cardViewMode,
                  builder: (context, _) {
                    return DropdownButton<String>(
                      value: AppState.instance.cardViewMode.value,
                      underline: const SizedBox(),
                      onChanged: (val) {
                        if (val != null) {
                          AppState.instance.updateSetting('cardViewMode', val);
                        }
                      },
                      items: [
                        DropdownMenuItem(
                          value: 'thumbnail',
                          child: Text(l.thumbnail),
                        ),
                        DropdownMenuItem(
                          value: 'detailed',
                          child: Text(l.detailed),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),

          _buildSectionHeader(context, l.reader),
          _buildCard(
            context,
            children: [
              _buildSettingItem(
                context,
                icon: Icons.menu_book_rounded,
                title: l.readerMode,
                trailing: ListenableBuilder(
                  listenable: AppState.instance.readerMode,
                  builder: (context, _) {
                    return DropdownButton<String>(
                      value: AppState.instance.readerMode.value,
                      underline: const SizedBox(),
                      onChanged: (val) {
                        if (val != null) {
                          AppState.instance.updateSetting('readerMode', val);
                        }
                      },
                      items: [
                        DropdownMenuItem(
                          value: 'webtoon',
                          child: Text(l.webtoon),
                        ),
                        DropdownMenuItem(
                          value: 'verticalPage',
                          child: Text(l.verticalPage),
                        ),
                        DropdownMenuItem(
                          value: 'horizontalPage',
                          child: Text(l.horizontalPage),
                        ),
                        DropdownMenuItem(
                          value: 'doublePage',
                          child: Text(l.doublePage),
                        ),
                      ],
                    );
                  },
                ),
              ),
              _buildSettingItem(
                context,
                icon: Icons.chrome_reader_mode_rounded,
                title: l.doublePageOrder,
                trailing: ListenableBuilder(
                  listenable: AppState.instance.doublePageOrder,
                  builder: (context, _) {
                    return DropdownButton<String>(
                      value: AppState.instance.doublePageOrder.value,
                      underline: const SizedBox(),
                      isDense: true,
                      selectedItemBuilder: (context) => [
                        Text(_compactDoublePageOrderLabel(l, 'japanese')),
                        Text(_compactDoublePageOrderLabel(l, 'international')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          AppState.instance.updateSetting(
                            'doublePageOrder',
                            val,
                          );
                        }
                      },
                      items: [
                        DropdownMenuItem(
                          value: 'japanese',
                          child: Text(l.doublePageJapanese),
                        ),
                        DropdownMenuItem(
                          value: 'international',
                          child: Text(l.doublePageInternational),
                        ),
                      ],
                    );
                  },
                ),
              ),
              _buildSettingItem(
                context,
                icon: Icons.swipe_rounded,
                title: l.pageTurnDirection,
                trailing: ListenableBuilder(
                  listenable: AppState.instance.pageTurnDirection,
                  builder: (context, _) {
                    return DropdownButton<String>(
                      value: AppState.instance.pageTurnDirection.value,
                      underline: const SizedBox(),
                      isDense: true,
                      selectedItemBuilder: (context) => [
                        Text(_compactPageTurnLabel(l, 'left')),
                        Text(_compactPageTurnLabel(l, 'right')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          AppState.instance.updateSetting(
                            'pageTurnDirection',
                            val,
                          );
                        }
                      },
                      items: [
                        DropdownMenuItem(
                          value: 'left',
                          child: Text(l.pageTurnLeft),
                        ),
                        DropdownMenuItem(
                          value: 'right',
                          child: Text(l.pageTurnRight),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),

          _buildSectionHeader(context, l.dataManagement),
          _buildCard(
            context,
            children: [
              _buildSettingItem(
                context,
                icon: Icons.delete_outline_rounded,
                title: l.clearCache,
                subtitle: l.clearCacheDesc,
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(l.clearCacheTitle),
                      content: Text(l.clearCacheBody),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(l.cancel),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(l.delete),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    try {
                      final cacheDir = await getTemporaryDirectory();
                      if (cacheDir.existsSync()) {
                        cacheDir.deleteSync(recursive: true);
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l.cacheCleared),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  }
                },
              ),
              _buildSettingItem(
                context,
                icon: Icons.refresh_rounded,
                iconColor: theme.colorScheme.error,
                title: l.resetApp,
                titleColor: theme.colorScheme.error,
                subtitle: l.resetAppDesc,
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(l.resetAppTitle),
                      content: Text(l.resetAppBody),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(l.cancel),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(
                            l.delete,
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true) {
                    await DbManager.resetAllData();
                    await AppState.instance.init();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l.resetSuccess),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),

          _buildSectionHeader(context, l.backupRestore),
          _buildCard(
            context,
            children: [
              _buildSettingItem(
                context,
                icon: Icons.ios_share_rounded,
                title: l.exportFavorites,
                onTap: () => _exportFavorites(context, l),
              ),
              _buildSettingItem(
                context,
                icon: Icons.file_download_rounded,
                title: l.importFavorites,
                onTap: () => _importFavorites(context, l),
              ),
            ],
          ),

          _buildSectionHeader(context, l.about),
          _buildCard(
            context,
            children: [
              _buildSettingItem(
                context,
                icon: Icons.info_outline_rounded,
                title: 'Donggong',
                subtitle: 'Version 2.0.0 • Modern Hitomi Reader',
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, {required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? iconColor,
    Color? titleColor,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Icon(
        icon,
        color: iconColor ?? theme.colorScheme.onSurfaceVariant,
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: titleColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: trailing != null
          ? ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Align(alignment: Alignment.centerRight, child: trailing),
            )
          : null,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Future<void> _exportFavorites(BuildContext context, L l) async {
    try {
      final favs = AppState.instance.favorites.value;
      final jsonMap = favs.toDonggongJson();
      final jsonString = jsonEncode(jsonMap);
      final now = DateTime.now();
      final fileName =
          'donggong_backup_${DateFormat('yyyyMMdd_HHmm').format(now)}.json';
      final bytes = Uint8List.fromList(utf8.encode(jsonString));

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: l.exportFavorites,
        fileName: fileName,
        allowedExtensions: ['json'],
        type: FileType.custom,
        bytes: bytes,
      );

      if (outputFile != null && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l.exportSuccess)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<void> _importFavorites(BuildContext context, L l) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonString = await file.readAsString();
        final Map<String, dynamic> jsonMap = jsonDecode(jsonString);

        final isDonggongFormat =
            jsonMap.containsKey('favoriteId') ||
            jsonMap.containsKey('favoriteArtist') ||
            jsonMap.containsKey('favoriteTag') ||
            jsonMap.containsKey('favoriteLanguage') ||
            jsonMap.containsKey('favoriteGroup') ||
            jsonMap.containsKey('favoriteParody') ||
            jsonMap.containsKey('favoriteCharacter');

        final isPupilFormat =
            jsonMap.containsKey('favorites') ||
            jsonMap.containsKey('favorite_tags');

        final newFavs = isDonggongFormat
            ? Favorites.fromDonggongJson(jsonMap)
            : isPupilFormat
            ? Favorites.fromPupilJson(jsonMap)
            : throw const FormatException('Unsupported favorites format');

        await AppState.instance.importFavorites(newFavs);

        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l.importSuccess)));
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    }
  }
}
