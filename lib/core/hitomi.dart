import 'dart:convert';
import 'dart:typed_data';
import '../network/http.dart';
import 'tag_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

class HitomiConstants {
  static const String cdnBase = 'https://ltn.gold-usergeneratedcontent.net';
  static const String tagIndexBase = 'https://tagindex.hitomi.la';
  static const int pageSize = 25;
  static const int nozomiRangeBytes = pageSize * 4; // 4 bytes per ID
}

class GalleryNotFoundException implements Exception {
  final int id;
  const GalleryNotFoundException(this.id);
  @override
  String toString() => 'Gallery $id not found (404)';
}

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

class GalleryImage {
  final String hash;
  final String url;
  final int width;
  final int height;

  const GalleryImage({
    required this.hash,
    required this.url,
    required this.width,
    required this.height,
  });
}

class Gallery {
  final int id;
  final String title;
  final String thumbnail;
  final List<String> artists;
  final List<String> groups;
  final List<String> characters;
  final List<String> parodys;
  final String type;
  final String? language;
  final List<String> tags;
  final List<GalleryImage> images;
  final int pageCount;
  final bool isError;
  final bool isLoading; // Added for loading state

  const Gallery({
    required this.id,
    required this.title,
    required this.thumbnail,
    required this.artists,
    this.groups = const [],
    this.characters = const [],
    this.parodys = const [],
    required this.type,
    this.language,
    required this.tags,
    this.images = const [],
    this.pageCount = 0,
    this.isError = false,
    this.isLoading = false,
  });

  factory Gallery.empty() => const Gallery(
    id: 0,
    title: '',
    thumbnail: '',
    artists: [],
    type: '',
    tags: [],
  );

  factory Gallery.loading(int id) => Gallery(
    id: id,
    title: '',
    thumbnail: '',
    artists: [],
    type: '',
    tags: [],
    isLoading: true,
  );

  factory Gallery.error(int id) => Gallery(
    id: id,
    title: 'Error loading gallery',
    thumbnail: '',
    artists: [],
    type: 'error',
    tags: [],
    isError: true,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Gallery &&
        other.id == id &&
        other.title == title &&
        other.thumbnail == thumbnail &&
        other.pageCount == pageCount &&
        other.isError == isError &&
        other.isLoading == isLoading;
  }

  @override
  int get hashCode =>
      Object.hash(id, title, thumbnail, pageCount, isError, isLoading);

  factory Gallery.fromJson(Map<String, dynamic> json) {
    // Helper for parsing Hitomi tag format
    List<String> parseTags(dynamic input, {bool isTag = false}) {
      if (input is! List) return [];
      return input
          .map((e) {
            if (e is String) return e;
            if (e is Map) {
              if (e.containsKey('artist')) return e['artist'] as String;
              if (e.containsKey('group')) return e['group'] as String;
              if (e.containsKey('character')) return e['character'] as String;
              if (e.containsKey('parody')) return e['parody'] as String;
              if (e.containsKey('tag')) {
                final tag = e['tag'] as String;
                if (!isTag) return tag;
                final female = e['female'] == '1' || e['female'] == 1;
                final male = e['male'] == '1' || e['male'] == 1;
                if (female) return 'female:$tag';
                if (male) return 'male:$tag';
                return 'tag:$tag';
              }
            }
            return '';
          })
          .where((e) => e.isNotEmpty)
          .cast<String>()
          .toList();
    }

    final id = json['id'] is int
        ? json['id']
        : int.parse(json['id'].toString());
    final files = (json['files'] as List?) ?? [];

    int pCount = files.length;
    if (pCount == 0 && json.containsKey('pageCount')) {
      pCount = json['pageCount'] is int
          ? json['pageCount']
          : int.tryParse(json['pageCount'].toString()) ?? 0;
    }

    // Thumbnail generation
    String thumb = '';
    if (files.isNotEmpty) {
      final hash = files[0]['hash'] as String;
      final suffix = hash.substring(hash.length - 1);
      final mid = hash.substring(hash.length - 3, hash.length - 1);
      thumb =
          'https://tn.gold-usergeneratedcontent.net/webpbigtn/$suffix/$mid/$hash.webp';
    }

    return Gallery(
      id: id,
      title: json['title'] ?? '',
      thumbnail: json['thumbnail'] ?? thumb,
      artists: parseTags(json['artists']),
      groups: parseTags(json['groups']),
      characters: parseTags(json['characters']),
      parodys: parseTags(json['parodys']),
      type: json['type'] ?? '',
      language: json['language'],
      tags: parseTags(json['tags'], isTag: true),
      pageCount: pCount,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'thumbnail': thumbnail,
    'artists': artists,
    'groups': groups,
    'characters': characters,
    'parodys': parodys,
    'type': type,
    'language': language,
    'tags': tags,
    'pageCount': pageCount, // Persist page count
  };
}

class TagSuggestion {
  final String tag;
  final int count;
  final String type;

  const TagSuggestion({
    required this.tag,
    required this.count,
    required this.type,
  });

  factory TagSuggestion.fromJson(List<dynamic> json) => TagSuggestion(
    tag: json[0] as String,
    count: json[1] is int ? json[1] : int.tryParse(json[1].toString()) ?? 0,
    type: json[2] as String,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Logic (HitomiManager)
// ─────────────────────────────────────────────────────────────────────────────

class HitomiManager {
  static final HitomiManager instance = HitomiManager._();
  HitomiManager._();
  static const Duration _ggCacheTtl = Duration(minutes: 5);

  // Simple In-Memory LRU Cache
  final Map<int, Gallery> _cache = {};
  final List<int> _cacheKeys = [];
  static const int _maxCacheSize = 100;
  String? _ggScriptCache;
  DateTime? _ggScriptFetchedAt;

  Gallery? _getFromCache(int id) {
    if (_cache.containsKey(id)) {
      // Refresh position (LRU)
      _cacheKeys.remove(id);
      _cacheKeys.add(id);
      return _cache[id];
    }
    return null;
  }

  void _addToCache(Gallery gallery) {
    if (_cache.containsKey(gallery.id)) {
      _cacheKeys.remove(gallery.id);
    } else if (_cacheKeys.length >= _maxCacheSize) {
      final oldest = _cacheKeys.removeAt(0);
      _cache.remove(oldest);
    }
    _cacheKeys.add(gallery.id);
    _cache[gallery.id] = gallery;
  }

  /// Get Gallery List (Recent/Index)
  Future<(List<Gallery>, int)> getList({int page = 1, String? lang}) async {
    try {
      final start = (page - 1) * HitomiConstants.nozomiRangeBytes;
      final end = page * HitomiConstants.nozomiRangeBytes - 1;

      final language = lang ?? 'korean';
      final url = '${HitomiConstants.cdnBase}/index-$language.nozomi';

      // Parallel requests: IDs and Total Count
      final responses = await Future.wait<dynamic>([
        HttpClient.fetch(url, headers: {'Range': 'bytes=$start-$end'}),
        HttpClient.getContentLength(url),
      ]);

      final res = responses[0] as HttpPayload;
      final totalBytes = responses[1] as int?;

      if (res.statusCode != 200 && res.statusCode != 206) {
        return (<Gallery>[], 0);
      }

      final totalCount = totalBytes != null ? totalBytes ~/ 4 : 0;
      final ids = _parseNozomi(res.bodyBytes);

      final galleries = await _fetchDetails(ids.toList());
      return (galleries, totalCount);
    } catch (_) {
      return (<Gallery>[], 0);
    }
  }

  /// Search Galleries
  Future<(List<Gallery>, int)> search(
    String query, {
    int page = 1,
    String defaultLang = 'all',
  }) async {
    final normalizedQuery = TagUtils.normalizeQuery(query);
    final terms = normalizedQuery
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (terms.isEmpty) return (<Gallery>[], 0);

    final hasLang = terms.any((t) => t.startsWith('language:'));
    final lang = hasLang ? 'all' : defaultLang;

    // Helper to fetch IDs for a single term
    Future<Set<int>> fetchIds(String term) async {
      final info = TagInfo.parse(term);
      final area = info.type;
      final tag = info.displayLabel;

      if (area == 'language') {
        final res = await HttpClient.get(
          '${HitomiConstants.cdnBase}/index-$tag.nozomi',
        );
        return res.statusCode == 200 ? _parseNozomi(res.bodyBytes) : {};
      }

      String url;
      if (area == 'female' || area == 'male') {
        url =
            '${HitomiConstants.cdnBase}/tag/$area:${Uri.encodeComponent(tag)}-$lang.nozomi';
      } else {
        url =
            '${HitomiConstants.cdnBase}/$area/${Uri.encodeComponent(tag)}-$lang.nozomi';
      }

      try {
        var res = await HttpClient.get(url);
        if (res.statusCode == 200) return _parseNozomi(res.bodyBytes);

        // Fallback to 'all' if not found in specific language
        if (res.statusCode == 404 && lang != 'all') {
          final fallbackUrl =
              '${HitomiConstants.cdnBase}/$area/${Uri.encodeComponent(tag)}-all.nozomi';
          res = await HttpClient.get(fallbackUrl);
          return res.statusCode == 200 ? _parseNozomi(res.bodyBytes) : {};
        }
        return {};
      } catch (_) {
        return {};
      }
    }

    // Intersect results
    final idSets = await Future.wait(terms.map(fetchIds));
    if (idSets.any((s) => s.isEmpty)) return (<Gallery>[], 0);

    idSets.sort((a, b) => a.length.compareTo(b.length));
    Set<int> common = idSets[0];
    for (int i = 1; i < idSets.length; i++) {
      common = common.intersection(idSets[i]);
    }

    final sortedIds = common.toList()..sort((a, b) => b.compareTo(a));
    final totalCount = sortedIds.length;

    final start = (page - 1) * HitomiConstants.pageSize;
    if (start >= totalCount) return (<Gallery>[], totalCount);

    final end = (start + HitomiConstants.pageSize).clamp(0, totalCount);
    final pagedIds = sortedIds.sublist(start, end);

    final galleries = await _fetchDetails(pagedIds);
    return (galleries, totalCount);
  }

  /// Fetch Gallery Detail (Full)
  Future<Gallery> getDetail(int id) async {
    final cached = _getFromCache(id);
    if (cached != null) return cached;

    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        final res = await HttpClient.fetch(
          '${HitomiConstants.cdnBase}/galleries/$id.js',
        );

        if (res.statusCode == 404) {
          throw GalleryNotFoundException(id);
        }

        final text = res.body.replaceFirst('var galleryinfo = ', '');
        final json = jsonDecode(text);

        final gallery = Gallery.fromJson(json);
        _addToCache(gallery);
        return gallery;
      } on GalleryNotFoundException {
        rethrow; // Don't retry 404s
      } catch (e) {
        retryCount++;
        if (retryCount >= maxRetries) break;
        await Future.delayed(
          Duration(seconds: 1 * retryCount),
        ); // Exponential backoff
      }
    }

    // Return error gallery after retries fail
    return Gallery.error(id);
  }

  /// Fetch Reader Data (Images + Metadata)
  Future<Gallery> getReaderData(int id) async {
    final cached = _getFromCache(id);
    if (cached != null && cached.images.isNotEmpty) return cached;

    try {
      final responses = await Future.wait<Object>([
        HttpClient.fetch('${HitomiConstants.cdnBase}/galleries/$id.js'),
        _getGgScript(),
      ]);

      final galleryResponse = responses[0] as dynamic;
      final galleryText = galleryResponse.body.replaceFirst(
        'var galleryinfo = ',
        '',
      );
      final galleryJson = jsonDecode(galleryText);
      final ggScript = responses[1] as String;

      final files = (galleryJson['files'] as List?);
      final images =
          files
              ?.map(
                (f) => GalleryImage(
                  hash: f['hash'],
                  width: f['width'],
                  height: f['height'],
                  url: _buildImageUrl(f['hash'], ggScript),
                ),
              )
              .toList() ??
          [];

      final baseGallery = Gallery.fromJson(galleryJson);
      final fullGallery = Gallery(
        id: baseGallery.id,
        title: baseGallery.title,
        thumbnail: baseGallery.thumbnail,
        artists: baseGallery.artists,
        groups: baseGallery.groups,
        characters: baseGallery.characters,
        parodys: baseGallery.parodys,
        type: baseGallery.type,
        language: baseGallery.language,
        tags: baseGallery.tags,
        pageCount: baseGallery.pageCount,
        images: images, // Added images
      );

      _addToCache(fullGallery);
      return fullGallery;
    } catch (_) {
      return Gallery.empty();
    }
  }

  Future<String> resolveImageUrl(
    String hash, {
    bool forceRefresh = false,
  }) async {
    final ggScript = await _getGgScript(forceRefresh: forceRefresh);
    return _buildImageUrl(hash, ggScript);
  }

  Future<List<TagSuggestion>> getTagSuggestions(String query) async {
    if (query.isEmpty) return [];
    final clean = query.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
    if (clean.isEmpty) return [];

    try {
      final path = clean.split('').join('/');
      final res = await HttpClient.fetch(
        '${HitomiConstants.tagIndexBase}/global/$path.json',
      );
      if (res.statusCode != 200) return [];

      final json = jsonDecode(res.body) as List;
      return json.take(20).map((x) => TagSuggestion.fromJson(x)).toList();
    } catch (_) {
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // Internal Helpers
  // ─────────────────────────────────────────────────────────────────────────────

  Future<List<Gallery>> getDetails(List<int> ids) async {
    return _fetchDetails(ids);
  }

  Future<List<Gallery>> _fetchDetails(List<int> ids) async {
    final results = await Future.wait(ids.map((id) => getDetail(id)));
    return results.where((g) => g.id != 0).toList();
  }

  Future<String> _getGgScript({bool forceRefresh = false}) async {
    final now = DateTime.now();
    final isFresh =
        !forceRefresh &&
        _ggScriptCache != null &&
        _ggScriptFetchedAt != null &&
        now.difference(_ggScriptFetchedAt!) < _ggCacheTtl;

    if (isFresh) return _ggScriptCache!;

    final response = await HttpClient.fetch('${HitomiConstants.cdnBase}/gg.js');
    if (response.statusCode != 200 || response.body.isEmpty) {
      if (_ggScriptCache != null) return _ggScriptCache!;
      throw Exception('Failed to fetch gg.js');
    }

    _ggScriptCache = response.body;
    _ggScriptFetchedAt = now;
    return _ggScriptCache!;
  }

  Set<int> _parseNozomi(Uint8List buf) {
    final ids = <int>{};
    final view = ByteData.sublistView(buf);
    for (int i = 0; i < buf.lengthInBytes; i += 4) {
      ids.add(view.getInt32(i, Endian.big));
    }
    return ids;
  }

  String _buildImageUrl(String hash, String gg) {
    final s =
        hash.substring(hash.length - 1) +
        hash.substring(hash.length - 3, hash.length - 1);
    final imageId = int.parse(s, radix: 16);

    final defaultDomainMatch = RegExp(r'var o = (\d)').firstMatch(gg);
    final defaultDomain =
        (int.tryParse(defaultDomainMatch?.group(1) ?? '0') ?? 0) + 1;

    final offsetDomainMatch = RegExp(r'o = (\d); break;').firstMatch(gg);
    final offsetDomain =
        (int.tryParse(offsetDomainMatch?.group(1) ?? '0') ?? 0) + 1;

    final commonKeyMatch = RegExp(r"b: '(\d+)/").firstMatch(gg);
    final commonKey = commonKeyMatch?.group(1) ?? '';

    final offsets = <int, int>{};
    final caseMatches = RegExp(r'case (\d+):').allMatches(gg);
    for (final m in caseMatches) {
      offsets[int.parse(m.group(1)!)] = offsetDomain;
    }

    final domain = offsets[imageId] ?? defaultDomain;
    return 'https://w$domain.gold-usergeneratedcontent.net/$commonKey/$imageId/$hash.webp';
  }
}
