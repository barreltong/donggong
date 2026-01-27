import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'database.dart';
import 'hitomi.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

class Favorites {
  final Set<int> galleries;
  final Set<String> artists;
  final Set<String> groups;
  final Set<String> characters;
  final Set<String> parodys;
  final Set<String> languages;
  final Set<String> tags;

  const Favorites({
    this.galleries = const {},
    this.artists = const {},
    this.groups = const {},
    this.characters = const {},
    this.parodys = const {},
    this.languages = const {},
    this.tags = const {},
  });

  bool isFavorite(String type, dynamic value) {
    switch (type) {
      case 'gallery':
        return galleries.contains(
          value is int ? value : int.tryParse(value.toString()) ?? 0,
        );
      case 'artist':
        return artists.contains(value);
      case 'group':
        return groups.contains(value);
      case 'character':
        return characters.contains(value);
      case 'series':
      case 'parody':
        return parodys.contains(value);
      case 'language':
        return languages.contains(value);
      case 'tag':
      case 'male':
      case 'female':
        return tags.contains(type == 'tag' ? 'tag:$value' : '$type:$value');
      default:
        return false;
    }
  }

  Favorites copyWith({
    Set<int>? galleries,
    Set<String>? artists,
    Set<String>? groups,
    Set<String>? characters,
    Set<String>? parodys,
    Set<String>? languages,
    Set<String>? tags,
  }) {
    return Favorites(
      galleries: galleries ?? this.galleries,
      artists: artists ?? this.artists,
      groups: groups ?? this.groups,
      characters: characters ?? this.characters,
      parodys: parodys ?? this.parodys,
      languages: languages ?? this.languages,
      tags: tags ?? this.tags,
    );
  }

  Favorites addItem(String type, String value) {
    switch (type) {
      case 'gallery':
        return copyWith(galleries: Set.from(galleries)..add(int.parse(value)));
      case 'artist':
        return copyWith(artists: Set.from(artists)..add(value));
      case 'group':
        return copyWith(groups: Set.from(groups)..add(value));
      case 'character':
        return copyWith(characters: Set.from(characters)..add(value));
      case 'series':
      case 'parody':
        return copyWith(parodys: Set.from(parodys)..add(value));
      case 'language':
        return copyWith(languages: Set.from(languages)..add(value));
      case 'tag':
      case 'male':
      case 'female':
        return copyWith(
          tags: Set.from(tags)
            ..add(type == 'tag' ? 'tag:$value' : '$type:$value'),
        );
      default:
        return this;
    }
  }

  Favorites removeItem(String type, String value) {
    switch (type) {
      case 'gallery':
        return copyWith(
          galleries: Set.from(galleries)..remove(int.parse(value)),
        );
      case 'artist':
        return copyWith(artists: Set.from(artists)..remove(value));
      case 'group':
        return copyWith(groups: Set.from(groups)..remove(value));
      case 'character':
        return copyWith(characters: Set.from(characters)..remove(value));
      case 'series':
      case 'parody':
        return copyWith(parodys: Set.from(parodys)..remove(value));
      case 'language':
        return copyWith(languages: Set.from(languages)..remove(value));
      case 'tag':
      case 'male':
      case 'female':
        return copyWith(
          tags: Set.from(tags)
            ..remove(type == 'tag' ? 'tag:$value' : '$type:$value'),
        );
      default:
        return this;
    }
  }

  List<String> get allChips {
    final list = <String>[];
    list.addAll(tags);
    for (var v in artists) {
      list.add('artist:$v');
    }
    for (var v in groups) {
      list.add('group:$v');
    }
    for (var v in characters) {
      list.add('character:$v');
    }
    for (var v in parodys) {
      list.add('series:$v');
    }
    for (var v in languages) {
      list.add('language:$v');
    }
    return list;
  }

  Map<String, dynamic> toV1Json() {
    return {
      'favoriteId': galleries.toList(),
      'favoriteArtist': artists.toList(),
      'favoriteTag': tags.toList(),
      'favoriteLanguage': languages.toList(),
      'favoriteGroup': groups.toList(),
      'favoriteParody': parodys.toList(),
      'favoriteCharacter': characters.toList(),
    };
  }

  factory Favorites.fromV1Json(Map<String, dynamic> json) {
    return Favorites(
      galleries: (json['favoriteId'] as List?)?.cast<int>().toSet() ?? {},
      artists: (json['favoriteArtist'] as List?)?.cast<String>().toSet() ?? {},
      tags: (json['favoriteTag'] as List?)?.cast<String>().toSet() ?? {},
      languages:
          (json['favoriteLanguage'] as List?)?.cast<String>().toSet() ?? {},
      groups: (json['favoriteGroup'] as List?)?.cast<String>().toSet() ?? {},
      parodys: (json['favoriteParody'] as List?)?.cast<String>().toSet() ?? {},
      characters:
          (json['favoriteCharacter'] as List?)?.cast<String>().toSet() ?? {},
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AppState (Signal Manager)
// ─────────────────────────────────────────────────────────────────────────────

class AppState {
  static final AppState instance = AppState._();
  AppState._();

  // Signals
  final ValueNotifier<Favorites> favorites = ValueNotifier(Favorites());
  final ValueNotifier<List<Gallery>> history = ValueNotifier([]);
  final ValueNotifier<List<String>> recentSearches = ValueNotifier([]);

  // Advanced Settings
  final ValueNotifier<String> appLanguage = ValueNotifier('ko');
  final ValueNotifier<String> themeModeKey = ValueNotifier(
    'dark',
  ); // 'light' | 'dark' | 'oled'
  final ValueNotifier<String> listingMode = ValueNotifier(
    'scroll',
  ); // 'scroll' | 'pagination'
  final ValueNotifier<String> readerMode = ValueNotifier(
    'verticalPage',
  ); // 'verticalPage' | 'horizontalPage' | 'webtoon'
  final ValueNotifier<String> cardViewMode = ValueNotifier(
    'detailed',
  ); // 'thumbnail' | 'detailed'
  final ValueNotifier<String> defaultLanguage = ValueNotifier('korean');

  // Initialization
  Future<void> init() async {
    await DbManager.init();
    await _loadSettings();
    await _loadFavorites();
    await _loadHistory();
    await _loadRecentSearches();
  }

  // ─── Settings ───
  Future<void> _loadSettings() async {
    final settings = await DbManager.loadSettings();
    if (settings.containsKey('themeModeKey')) {
      themeModeKey.value = settings['themeModeKey']!;
    } else if (settings.containsKey('themeMode')) {
      // Legacy support
      final mode = settings['themeMode'];
      if (mode == 'ThemeMode.light') {
        themeModeKey.value = 'light';
        await updateSetting('themeModeKey', 'light');
      } else if (mode == 'ThemeMode.dark') {
        themeModeKey.value = 'dark';
        await updateSetting('themeModeKey', 'dark');
      } else {
        themeModeKey.value = 'system';
        await updateSetting('themeModeKey', 'system');
      }
    }

    if (settings.containsKey('appLanguage')) {
      appLanguage.value = settings['appLanguage']!;
    }
    if (settings.containsKey('listingMode')) {
      listingMode.value = settings['listingMode']!;
    }
    if (settings.containsKey('readerMode')) {
      readerMode.value = settings['readerMode']!;
    }
    if (settings.containsKey('cardViewMode')) {
      cardViewMode.value = settings['cardViewMode']!;
    }
    if (settings.containsKey('defaultLanguage')) {
      defaultLanguage.value = settings['defaultLanguage']!;
    }
  }

  Future<void> updateSetting(String key, String value) async {
    switch (key) {
      case 'appLanguage':
        appLanguage.value = value;
        break;
      case 'themeModeKey':
        themeModeKey.value = value;
        break;
      case 'listingMode':
        listingMode.value = value;
        break;
      case 'readerMode':
        readerMode.value = value;
        break;
      case 'cardViewMode':
        cardViewMode.value = value;
        break;
      case 'defaultLanguage':
        defaultLanguage.value = value;
        break;
    }
    await DbManager.saveSetting(key, value);
  }

  Future<void> toggleTheme() async {
    if (themeModeKey.value == 'light') {
      await updateSetting('themeModeKey', 'dark');
    } else {
      await updateSetting('themeModeKey', 'light');
    }
  }

  // ─── Favorites ───
  Future<void> _loadFavorites() async {
    final rows = await DbManager.getFavorites();

    // Build sets locally first
    final galleries = <int>{};
    final artists = <String>{};
    final groups = <String>{};
    final characters = <String>{};
    final parodys = <String>{};
    final languages = <String>{};
    final tags = <String>{};

    for (var row in rows) {
      final type = row['type'] as String;
      final value = row['value'] as String;

      switch (type) {
        case 'gallery':
          galleries.add(int.parse(value));
          break;
        case 'artist':
          artists.add(value);
          break;
        case 'group':
          groups.add(value);
          break;
        case 'character':
          characters.add(value);
          break;
        case 'series': // 'series' in DB
          parodys.add(value);
          break;
        case 'language':
          languages.add(value);
          break;
        case 'tag':
        case 'male':
        case 'female':
          // Reconstruct tag string
          tags.add(type == 'tag' ? 'tag:$value' : '$type:$value');
          break;
      }
    }

    favorites.value = Favorites(
      galleries: galleries,
      artists: artists,
      groups: groups,
      characters: characters,
      parodys: parodys,
      languages: languages,
      tags: tags,
    );
  }

  Future<void> toggleFavorite(
    String type,
    String value, {
    Gallery? gallery,
  }) async {
    final current = favorites.value;
    if (current.isFavorite(type, value)) {
      favorites.value = current.removeItem(type, value);
      await DbManager.removeFavorite(type, value);
    } else {
      favorites.value = current.addItem(type, value);
      await DbManager.addFavorite(type, value);

      // If adding a gallery, ensure it's cached
      if (type == 'gallery' && gallery != null) {
        await DbManager.cacheGallery(
          int.parse(value),
          jsonEncode(gallery.toJson()),
        );
      }
    }
  }

  Future<void> importFavorites(Favorites newFavs) async {
    final batch = DbManager.db.batch();

    // Delete all existing first (part of batch for atomicity)
    batch.delete('favorites');

    // Insert all
    for (final id in newFavs.galleries) {
      batch.insert('favorites', {'type': 'gallery', 'value': id.toString()});
    }
    for (final val in newFavs.artists) {
      batch.insert('favorites', {'type': 'artist', 'value': val});
    }
    for (final val in newFavs.groups) {
      batch.insert('favorites', {'type': 'group', 'value': val});
    }
    for (final val in newFavs.characters) {
      batch.insert('favorites', {'type': 'character', 'value': val});
    }
    for (final val in newFavs.parodys) {
      batch.insert('favorites', {
        'type': 'series',
        'value': val,
      }); // 'series' in DB
    }
    for (final val in newFavs.languages) {
      batch.insert('favorites', {'type': 'language', 'value': val});
    }
    for (final val in newFavs.tags) {
      // tags set contains "type:value" string.
      // Need to split?
      // V1 TagChip logic: "female:xxx" -> type=female, value=xxx.
      // Favorites.add logic: type=tag -> "tag:xxx", type=male -> "male:xxx".
      // So the string in `tags` Set IS "type:value".
      // DB expects type and value separately.
      final parts = val.split(':');
      if (parts.length >= 2) {
        final type = parts[0];
        final value = parts.sublist(1).join(':');
        batch.insert('favorites', {
          'type': type,
          'value': value,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      } else {
        // Fallback for non-namespaced tags (legacy/simple tags)
        batch.insert('favorites', {
          'type': 'tag',
          'value': val,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }

    await batch.commit(noResult: true);
    favorites.value = newFavs;
  }

  // ─── History ───
  Future<void> _loadHistory() async {
    final ids = await DbManager.getRecentViewedIds();
    if (ids.isEmpty) {
      history.value = [];
      return;
    }

    // Fetch cached details from DB
    final cachedMaps = await DbManager.getCachedGalleries(ids);
    final List<Gallery> loaded = [];

    for (var map in cachedMaps) {
      try {
        final json = jsonDecode(map['json'] as String);
        loaded.add(Gallery.fromJson(json));
      } catch (_) {}
    }

    // Sort by timestamp (need to join with recent_viewed table? DbManager.getRecentViewedIds already sorts by timestamp DESC)
    // But getCachedGalleries doesn't preserve order. We need to reorder.
    final galleryMap = {for (var g in loaded) g.id: g};
    final ordered = ids
        .map((id) => galleryMap[id])
        .whereType<Gallery>()
        .toList();

    history.value = ordered;
  }

  Future<void> addToHistory(Gallery gallery) async {
    await DbManager.addRecentViewed(gallery.id);
    await DbManager.cacheGallery(gallery.id, jsonEncode(gallery.toJson()));

    // Update in-memory list
    final current = List<Gallery>.from(history.value);
    current.removeWhere((g) => g.id == gallery.id);
    current.insert(0, gallery);
    if (current.length > 50) current.removeLast();

    history.value = current;
  }

  Future<void> removeFromHistory(int id) async {
    await DbManager.db.delete(
      'recent_viewed',
      where: 'id = ?',
      whereArgs: [id],
    );
    final current = List<Gallery>.from(history.value);
    current.removeWhere((g) => g.id == id);
    history.value = current;
  }

  Future<void> clearHistory() async {
    await DbManager.db.delete('recent_viewed');
    history.value = [];
  }

  // ─── Recent Searches ───
  Future<void> _loadRecentSearches() async {
    recentSearches.value = await DbManager.getRecentSearches();
  }

  Future<void> addRecentSearch(String query) async {
    await DbManager.addRecentSearch(query);
    recentSearches.value = await DbManager.getRecentSearches();
  }

  Future<void> removeRecentSearch(String query) async {
    await DbManager.removeRecentSearch(query);
    recentSearches.value = await DbManager.getRecentSearches();
  }
}
