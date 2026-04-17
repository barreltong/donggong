import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'database.dart';
import 'hitomi.dart';
import 'tag_utils.dart';

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

  static String _normalizeValue(String value) {
    return TagUtils.normalizeTagValue(value);
  }

  static String _canonicalType(String type) {
    return type == 'parody' ? 'series' : type;
  }

  static bool _isTagType(String type) {
    switch (_canonicalType(type)) {
      case 'tag':
      case 'male':
      case 'female':
        return true;
      default:
        return false;
    }
  }

  static String _chipLabel(String type, String value) {
    return '${_canonicalType(type)}:$value';
  }

  static Set<String> _normalizedSet(List<dynamic>? values) {
    return (values?.cast<String>() ?? []).map(_normalizeValue).toSet();
  }

  Set<String>? _stringSetForType(String type) {
    switch (_canonicalType(type)) {
      case 'artist':
        return artists;
      case 'group':
        return groups;
      case 'character':
        return characters;
      case 'series':
        return parodys;
      case 'language':
        return languages;
      default:
        return null;
    }
  }

  Favorites _copyWithUpdatedSet(String type, Set<String> values) {
    switch (_canonicalType(type)) {
      case 'artist':
        return copyWith(artists: values);
      case 'group':
        return copyWith(groups: values);
      case 'character':
        return copyWith(characters: values);
      case 'series':
        return copyWith(parodys: values);
      case 'language':
        return copyWith(languages: values);
      default:
        return this;
    }
  }

  bool isFavorite(String type, dynamic value) {
    final canonicalType = _canonicalType(type);
    final stringValue = value.toString();
    switch (canonicalType) {
      case 'gallery':
        return galleries.contains(
          value is int ? value : int.tryParse(stringValue) ?? 0,
        );
      case 'artist':
      case 'group':
      case 'character':
      case 'series':
      case 'language':
        return _stringSetForType(canonicalType)!.contains(
          _normalizeValue(stringValue),
        );
      default:
        return _isTagType(canonicalType)
            ? tags.contains(TagUtils.buildKey(canonicalType, stringValue))
            : false;
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
    final canonicalType = _canonicalType(type);
    final normalizedValue = _normalizeValue(value);
    switch (canonicalType) {
      case 'gallery':
        return copyWith(galleries: Set.from(galleries)..add(int.parse(value)));
      case 'artist':
      case 'group':
      case 'character':
      case 'series':
      case 'language':
        return _copyWithUpdatedSet(
          canonicalType,
          Set<String>.from(_stringSetForType(canonicalType)!)
            ..add(normalizedValue),
        );
      default:
        if (!_isTagType(canonicalType)) return this;
        return copyWith(
          tags: Set.from(tags)..add(TagUtils.buildKey(canonicalType, value)),
        );
    }
  }

  Favorites removeItem(String type, String value) {
    final canonicalType = _canonicalType(type);
    final normalizedValue = _normalizeValue(value);
    switch (canonicalType) {
      case 'gallery':
        return copyWith(
          galleries: Set.from(galleries)..remove(int.parse(value)),
        );
      case 'artist':
      case 'group':
      case 'character':
      case 'series':
      case 'language':
        return _copyWithUpdatedSet(
          canonicalType,
          Set<String>.from(_stringSetForType(canonicalType)!)
            ..remove(normalizedValue),
        );
      default:
        if (!_isTagType(canonicalType)) return this;
        return copyWith(
          tags: Set.from(tags)..remove(TagUtils.buildKey(canonicalType, value)),
        );
    }
  }

  List<String> get allChips {
    final list = <String>[];
    list.addAll(tags);
    list.addAll(artists.map((v) => _chipLabel('artist', v)));
    list.addAll(groups.map((v) => _chipLabel('group', v)));
    list.addAll(characters.map((v) => _chipLabel('character', v)));
    list.addAll(parodys.map((v) => _chipLabel('series', v)));
    list.addAll(languages.map((v) => _chipLabel('language', v)));
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
      artists: _normalizedSet(json['favoriteArtist'] as List?),
      tags: ((json['favoriteTag'] as List?)?.cast<String>() ?? [])
          .map(TagUtils.normalizeTagLabel)
          .toSet(),
      languages: _normalizedSet(json['favoriteLanguage'] as List?),
      groups: _normalizedSet(json['favoriteGroup'] as List?),
      parodys: _normalizedSet(json['favoriteParody'] as List?),
      characters: _normalizedSet(json['favoriteCharacter'] as List?),
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
  final ValueNotifier<String?> pendingSearch = ValueNotifier(null);

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
  String _normalizeFavoriteValue(String type, String value) {
    return type == 'gallery' ? value : TagUtils.normalizeTagValue(value);
  }

  void _addFavoriteToCollections({
    required String type,
    required String value,
    required Set<int> galleries,
    required Set<String> artists,
    required Set<String> groups,
    required Set<String> characters,
    required Set<String> parodys,
    required Set<String> languages,
    required Set<String> tags,
  }) {
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
      case 'series':
        parodys.add(value);
        break;
      case 'language':
        languages.add(value);
        break;
      case 'tag':
      case 'male':
      case 'female':
        tags.add(TagUtils.buildKey(type, value));
        break;
    }
  }

  void _insertFavoriteBatch(Batch batch, String type, Iterable<String> values) {
    for (final value in values) {
      batch.insert('favorites', {
        'type': type,
        'value': _normalizeFavoriteValue(type, value),
      });
    }
  }

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
    final rowsToNormalize = <({String type, String from, String to})>[];

    for (var row in rows) {
      final type = row['type'] as String;
      final value = row['value'] as String;
      final normalizedValue = _normalizeFavoriteValue(type, value);

      if (type != 'gallery' && value != normalizedValue) {
        rowsToNormalize.add((type: type, from: value, to: normalizedValue));
      }

      _addFavoriteToCollections(
        type: type,
        value: normalizedValue,
        galleries: galleries,
        artists: artists,
        groups: groups,
        characters: characters,
        parodys: parodys,
        languages: languages,
        tags: tags,
      );
    }

    if (rowsToNormalize.isNotEmpty) {
      await DbManager.normalizeFavorites(rowsToNormalize);
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
    final normalizedValue = _normalizeFavoriteValue(type, value);
    final current = favorites.value;
    if (current.isFavorite(type, normalizedValue)) {
      favorites.value = current.removeItem(type, normalizedValue);
      await DbManager.removeFavorite(type, normalizedValue);
    } else {
      favorites.value = current.addItem(type, normalizedValue);
      await DbManager.addFavorite(type, normalizedValue);

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
    _insertFavoriteBatch(batch, 'artist', newFavs.artists);
    _insertFavoriteBatch(batch, 'group', newFavs.groups);
    _insertFavoriteBatch(batch, 'character', newFavs.characters);
    _insertFavoriteBatch(batch, 'series', newFavs.parodys);
    _insertFavoriteBatch(batch, 'language', newFavs.languages);
    for (final val in newFavs.tags) {
      final tag = TagInfo.parse(val);
      batch.insert('favorites', {
        'type': tag.type,
        'value': tag.value,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
    await _loadFavorites();
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
