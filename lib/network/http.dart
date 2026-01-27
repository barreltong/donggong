import 'dart:async';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// Pure HTTP Client with SNI/DPI Bypass capability
class HttpClient {
  static const MethodChannel _channel = MethodChannel('com.donggong/dpi');
  
  static const Map<String, String> defaultHeaders = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Referer': 'https://hitomi.la/',
  };

  /// Fetch content using platform-specific DPI bypass if needed
  static Future<http.Response> fetch(String url, {Map<String, String>? headers}) async {
    final mergedHeaders = {...defaultHeaders, ...?headers};
    try {
      final Map<dynamic, dynamic> result = await _channel.invokeMethod('fetch', {
        'url': url,
        'headers': mergedHeaders,
      });
      final String body = result['body'] as String;
      final int statusCode = result['statusCode'] as int;
      return http.Response(body, statusCode);
    } on PlatformException catch (_) {
      // Fallback to standard HTTP
      return http.get(Uri.parse(url), headers: mergedHeaders);
    } catch (_) {
      return http.get(Uri.parse(url), headers: mergedHeaders);
    }
  }

  /// Standard GET request
  static Future<http.Response> get(String url, {Map<String, String>? headers}) {
    return http.get(
      Uri.parse(url),
      headers: {...defaultHeaders, ...?headers},
    );
  }

  /// Get content length via Range header (for finding last page)
  static Future<int?> getContentLength(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
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
