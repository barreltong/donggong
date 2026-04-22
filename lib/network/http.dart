import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class HttpPayload {
  final Uint8List bodyBytes;
  final int statusCode;
  final Map<String, String> headers;

  const HttpPayload({
    required this.bodyBytes,
    required this.statusCode,
    this.headers = const {},
  });

  String get body => utf8.decode(bodyBytes, allowMalformed: true);

  factory HttpPayload.fromResponse(http.Response response) {
    return HttpPayload(
      bodyBytes: response.bodyBytes,
      statusCode: response.statusCode,
      headers: response.headers,
    );
  }

  factory HttpPayload.fromPlatformResult(Map<dynamic, dynamic> result) {
    final rawBytes = result['bodyBytes'];
    final bodyBytes = rawBytes is Uint8List
        ? rawBytes
        : rawBytes is List<int>
        ? Uint8List.fromList(rawBytes)
        : Uint8List.fromList(utf8.encode((result['body'] as String?) ?? ''));
    final rawHeaders = result['headers'];
    final headers = rawHeaders is Map
        ? rawHeaders.map(
            (key, value) =>
                MapEntry(key.toString().toLowerCase(), value.toString()),
          )
        : const <String, String>{};

    return HttpPayload(
      bodyBytes: bodyBytes,
      statusCode: result['statusCode'] as int? ?? 0,
      headers: headers,
    );
  }
}

/// Pure HTTP Client with SNI/DPI Bypass capability
class HttpClient {
  static const MethodChannel _channel = MethodChannel('com.donggong/dpi');

  static const Map<String, String> defaultHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Referer': 'https://hitomi.la/',
  };

  /// Fetch content using platform-specific DPI bypass if needed
  static Future<HttpPayload> fetch(
    String url, {
    Map<String, String>? headers,
  }) async {
    final mergedHeaders = {...defaultHeaders, ...?headers};
    try {
      final Map<dynamic, dynamic> result = await _channel.invokeMethod(
        'fetch',
        {'url': url, 'headers': mergedHeaders},
      );
      return HttpPayload.fromPlatformResult(result);
    } on PlatformException catch (_) {
      // Fallback to standard HTTP
      return get(url, headers: mergedHeaders);
    } catch (_) {
      return get(url, headers: mergedHeaders);
    }
  }

  /// Standard GET request
  static Future<HttpPayload> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    final response = await http.get(
      Uri.parse(url),
      headers: {...defaultHeaders, ...?headers},
    );
    return HttpPayload.fromResponse(response);
  }

  /// Get content length via Range header (for finding last page)
  static Future<int?> getContentLength(String url) async {
    try {
      final response = await get(
        url,
        headers: {...defaultHeaders, 'Range': 'bytes=0-3'},
      );
      if (response.statusCode == 206) {
        final contentRange = response.headers['content-range'];
        if (contentRange != null) {
          final match = RegExp(r'/(\d+)$').firstMatch(contentRange);
          if (match != null) {
            return int.tryParse(match.group(1)!);
          }
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
