import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'database.dart';
import 'hitomi.dart';
import 'tag_utils.dart';

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
        return _stringSetForType(
          canonicalType,
        )!.contains(_normalizeValue(stringValue));
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

  Map<String, dynamic> toDonggongJson() {
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

  factory Favorites.fromDonggongJson(Map<String, dynamic> json) {
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

  factory Favorites.fromPupilJson(Map<String, dynamic> json) {
    final galleries = ((json['favorites'] as List?) ?? [])
        .map((value) => value is int ? value : int.tryParse(value.toString()))
        .whereType<int>()
        .toSet();

    final artists = <String>{};
    final groups = <String>{};
    final characters = <String>{};
    final parodys = <String>{};
    final languages = <String>{};
    final tags = <String>{};

    final favoriteTags = json['favorite_tags'] as List?;
    if (favoriteTags != null) {
      for (final item in favoriteTags) {
        if (item is! Map) continue;

        final rawArea = item['area']?.toString();
        final rawTag = item['tag']?.toString();
        if (rawArea == null || rawTag == null || rawTag.isEmpty) continue;

        final area = _canonicalType(rawArea);
        final value = _normalizeValue(rawTag);

        switch (area) {
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
            tags.add(TagUtils.buildKey(area, value));
            break;
        }
      }
    }

    return Favorites(
      galleries: galleries,
      artists: artists,
      groups: groups,
      characters: characters,
      parodys: parodys,
      languages: languages,
      tags: tags,
    );
  }
}

class AppState {
  static final AppState instance = AppState._();
  AppState._();

  final ValueNotifier<Favorites> favorites = ValueNotifier(Favorites());
  final ValueNotifier<List<Gallery>> history = ValueNotifier([]);
  final ValueNotifier<List<String>> recentSearches = ValueNotifier([]);
  final ValueNotifier<String?> pendingSearch = ValueNotifier(null);

  final ValueNotifier<String> appLanguage = ValueNotifier('ko');
  final ValueNotifier<String> themeModeKey = ValueNotifier('dark');
  final ValueNotifier<String> listingMode = ValueNotifier('scroll');
  final ValueNotifier<String> readerMode = ValueNotifier('verticalPage');
  final ValueNotifier<String> doublePageOrder = ValueNotifier('japanese');
  final ValueNotifier<String> pageTurnDirection = ValueNotifier('left');
  final ValueNotifier<String> cardViewMode = ValueNotifier('detailed');
  final ValueNotifier<String> defaultLanguage = ValueNotifier('korean');

  late final _SettingsController _settings = _SettingsController(this);
  late final _FavoritesController _favoritesController = _FavoritesController(
    this,
  );
  late final _HistoryController _historyController = _HistoryController(this);
  late final _RecentSearchesController _recentSearchesController =
      _RecentSearchesController(this);

  Future<void> init() async {
    await DbManager.init();
    await _settings.load();
    await _favoritesController.load();
    await _historyController.load();
    await _recentSearchesController.load();
  }

  Future<void> updateSetting(String key, String value) {
    return _settings.update(key, value);
  }

  Future<void> toggleTheme() {
    return _settings.toggleTheme();
  }

  Future<void> toggleFavorite(String type, String value, {Gallery? gallery}) {
    return _favoritesController.toggle(type, value, gallery: gallery);
  }

  Future<void> importFavorites(Favorites newFavs) {
    return _favoritesController.importFavorites(newFavs);
  }

  Future<void> addToHistory(Gallery gallery) {
    return _historyController.add(gallery);
  }

  Future<void> removeFromHistory(int id) {
    return _historyController.remove(id);
  }

  Future<void> clearHistory() {
    return _historyController.clear();
  }

  Future<void> addRecentSearch(String query) {
    return _recentSearchesController.add(query);
  }

  Future<void> removeRecentSearch(String query) {
    return _recentSearchesController.remove(query);
  }
}

class _SettingsController {
  _SettingsController(this.app);

  final AppState app;

  static const _notifierMap = <String, String>{
    'appLanguage': 'appLanguage',
    'themeModeKey': 'themeModeKey',
    'listingMode': 'listingMode',
    'readerMode': 'readerMode',
    'doublePageOrder': 'doublePageOrder',
    'pageTurnDirection': 'pageTurnDirection',
    'cardViewMode': 'cardViewMode',
    'defaultLanguage': 'defaultLanguage',
  };

  ValueNotifier<String>? _notifierForKey(String key) {
    switch (_notifierMap[key]) {
      case 'appLanguage':
        return app.appLanguage;
      case 'themeModeKey':
        return app.themeModeKey;
      case 'listingMode':
        return app.listingMode;
      case 'readerMode':
        return app.readerMode;
      case 'doublePageOrder':
        return app.doublePageOrder;
      case 'pageTurnDirection':
        return app.pageTurnDirection;
      case 'cardViewMode':
        return app.cardViewMode;
      case 'defaultLanguage':
        return app.defaultLanguage;
      default:
        return null;
    }
  }

  Future<void> load() async {
    final settings = await DbManager.loadSettings();
    if (settings.containsKey('themeModeKey')) {
      app.themeModeKey.value = settings['themeModeKey']!;
    } else if (settings.containsKey('themeMode')) {
      final mode = settings['themeMode'];
      if (mode == 'ThemeMode.light') {
        app.themeModeKey.value = 'light';
        await update('themeModeKey', 'light');
      } else if (mode == 'ThemeMode.dark') {
        app.themeModeKey.value = 'dark';
        await update('themeModeKey', 'dark');
      } else {
        app.themeModeKey.value = 'system';
        await update('themeModeKey', 'system');
      }
    }

    for (final entry in settings.entries) {
      final notifier = _notifierForKey(entry.key);
      if (notifier != null) {
        notifier.value = entry.value;
      }
    }
  }

  Future<void> update(String key, String value) async {
    final notifier = _notifierForKey(key);
    if (notifier == null) return;
    notifier.value = value;
    await DbManager.saveSetting(key, value);
  }

  Future<void> toggleTheme() async {
    await update(
      'themeModeKey',
      app.themeModeKey.value == 'light' ? 'dark' : 'light',
    );
  }
}

class _FavoritesController {
  _FavoritesController(this.app);

  final AppState app;

  String normalizeValue(String type, String value) {
    return type == 'gallery' ? value : TagUtils.normalizeTagValue(value);
  }

  void _addToCollections({
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

  void _insertBatch(Batch batch, String type, Iterable<String> values) {
    for (final value in values) {
      batch.insert('favorites', {
        'type': type,
        'value': normalizeValue(type, value),
      });
    }
  }

  Future<void> load() async {
    final rows = await DbManager.getFavorites();
    final galleries = <int>{};
    final artists = <String>{};
    final groups = <String>{};
    final characters = <String>{};
    final parodys = <String>{};
    final languages = <String>{};
    final tags = <String>{};
    final rowsToNormalize = <({String type, String from, String to})>[];

    for (final row in rows) {
      final type = row['type'] as String;
      final value = row['value'] as String;
      final normalizedValue = normalizeValue(type, value);

      if (type != 'gallery' && value != normalizedValue) {
        rowsToNormalize.add((type: type, from: value, to: normalizedValue));
      }

      _addToCollections(
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

    app.favorites.value = Favorites(
      galleries: galleries,
      artists: artists,
      groups: groups,
      characters: characters,
      parodys: parodys,
      languages: languages,
      tags: tags,
    );
  }

  Future<void> toggle(String type, String value, {Gallery? gallery}) async {
    final normalizedValue = normalizeValue(type, value);
    final current = app.favorites.value;
    if (current.isFavorite(type, normalizedValue)) {
      app.favorites.value = current.removeItem(type, normalizedValue);
      await DbManager.removeFavorite(type, normalizedValue);
      return;
    }

    app.favorites.value = current.addItem(type, normalizedValue);
    await DbManager.addFavorite(type, normalizedValue);
    if (type == 'gallery' && gallery != null) {
      await DbManager.cacheGallery(
        int.parse(value),
        jsonEncode(gallery.toJson()),
      );
    }
  }

  Future<void> importFavorites(Favorites newFavs) async {
    final batch = DbManager.db.batch();
    batch.delete('favorites');

    for (final id in newFavs.galleries) {
      batch.insert('favorites', {'type': 'gallery', 'value': id.toString()});
    }
    _insertBatch(batch, 'artist', newFavs.artists);
    _insertBatch(batch, 'group', newFavs.groups);
    _insertBatch(batch, 'character', newFavs.characters);
    _insertBatch(batch, 'series', newFavs.parodys);
    _insertBatch(batch, 'language', newFavs.languages);
    for (final val in newFavs.tags) {
      final tag = TagInfo.parse(val);
      batch.insert('favorites', {
        'type': tag.type,
        'value': tag.value,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
    await load();
  }
}

class _HistoryController {
  _HistoryController(this.app);

  final AppState app;

  Future<void> load() async {
    final ids = await DbManager.getRecentViewedIds();
    if (ids.isEmpty) {
      app.history.value = [];
      return;
    }

    final cachedMaps = await DbManager.getCachedGalleries(ids);
    final loaded = <Gallery>[];
    for (final map in cachedMaps) {
      try {
        loaded.add(Gallery.fromJson(jsonDecode(map['json'] as String)));
      } catch (_) {}
    }

    final galleryMap = {for (final gallery in loaded) gallery.id: gallery};
    app.history.value = ids
        .map((id) => galleryMap[id])
        .whereType<Gallery>()
        .toList();
  }

  Future<void> add(Gallery gallery) async {
    await DbManager.addRecentViewed(gallery.id);
    await DbManager.cacheGallery(gallery.id, jsonEncode(gallery.toJson()));

    final current = List<Gallery>.from(app.history.value);
    current.removeWhere((g) => g.id == gallery.id);
    current.insert(0, gallery);
    if (current.length > 50) current.removeLast();
    app.history.value = current;
  }

  Future<void> remove(int id) async {
    await DbManager.db.delete(
      'recent_viewed',
      where: 'id = ?',
      whereArgs: [id],
    );
    final current = List<Gallery>.from(app.history.value)
      ..removeWhere((g) => g.id == id);
    app.history.value = current;
  }

  Future<void> clear() async {
    await DbManager.db.delete('recent_viewed');
    app.history.value = [];
  }
}

class _RecentSearchesController {
  _RecentSearchesController(this.app);

  final AppState app;

  Future<void> load() async {
    app.recentSearches.value = await DbManager.getRecentSearches();
  }

  Future<void> add(String query) async {
    await DbManager.addRecentSearch(query);
    await load();
  }

  Future<void> remove(String query) async {
    await DbManager.removeRecentSearch(query);
    await load();
  }
}
