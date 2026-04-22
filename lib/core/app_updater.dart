import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class OtaRelease {
  final String version;
  final String assetName;
  final String downloadUrl;
  final String pageUrl;
  final String? notes;

  const OtaRelease({
    required this.version,
    required this.assetName,
    required this.downloadUrl,
    required this.pageUrl,
    this.notes,
  });
}

class OtaInstallResult {
  final bool installStarted;
  final bool openedSettings;

  const OtaInstallResult({
    required this.installStarted,
    required this.openedSettings,
  });
}

class AppUpdater {
  AppUpdater._();

  static const String _repo = 'barreltong/donggong';
  static const MethodChannel _channel = MethodChannel('com.donggong/ota');
  static final AppUpdater instance = AppUpdater._();

  Future<OtaRelease?> fetchLatestRelease() async {
    if (!Platform.isAndroid) return null;

    final response = await http.get(
      Uri.parse('https://api.github.com/repos/$_repo/releases/latest'),
      headers: const {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2022-11-28',
        'User-Agent': 'Donggong-App',
      },
    );

    if (response.statusCode != 200) {
      throw HttpException(
        'Failed to fetch latest release (${response.statusCode})',
      );
    }

    final Map<String, dynamic> json =
        jsonDecode(response.body) as Map<String, dynamic>;
    final assets = (json['assets'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();

    Map<String, dynamic>? apkAsset;
    for (final asset in assets) {
      final name = (asset['name'] as String? ?? '').toLowerCase();
      if (name.endsWith('.apk')) {
        apkAsset = asset;
        break;
      }
    }

    if (apkAsset == null) return null;

    return OtaRelease(
      version: _normalizeVersion(json['tag_name'] as String? ?? ''),
      assetName: apkAsset['name'] as String,
      downloadUrl: apkAsset['browser_download_url'] as String,
      pageUrl: json['html_url'] as String? ?? '',
      notes: json['body'] as String?,
    );
  }

  bool isUpdateAvailable({
    required String currentVersion,
    required String latestVersion,
  }) {
    return _compareVersions(latestVersion, currentVersion) > 0;
  }

  Future<File> downloadRelease(
    OtaRelease release, {
    ValueChanged<double>? onProgress,
  }) async {
    final directory = await getTemporaryDirectory();
    final file = File(p.join(directory.path, release.assetName));
    final request = http.Request('GET', Uri.parse(release.downloadUrl));
    request.headers['User-Agent'] = 'Donggong-App';

    final response = await request.send();
    if (response.statusCode != 200) {
      throw HttpException('Failed to download update (${response.statusCode})');
    }

    final sink = file.openWrite();
    final total = response.contentLength;
    var received = 0;

    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total != null && total > 0) {
          onProgress?.call(received / total);
        }
      }
    } finally {
      await sink.close();
    }

    onProgress?.call(1);
    return file;
  }

  Future<bool> canRequestPackageInstalls() async {
    if (!Platform.isAndroid) return false;
    return await _channel.invokeMethod<bool>('canRequestPackageInstalls') ??
        false;
  }

  Future<void> openInstallPermissionSettings() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod('openInstallPermissionSettings');
  }

  Future<OtaInstallResult> installApk(File file) async {
    if (!Platform.isAndroid) {
      return const OtaInstallResult(
        installStarted: false,
        openedSettings: false,
      );
    }

    final raw = await _channel.invokeMapMethod<String, dynamic>('installApk', {
      'path': file.path,
    });

    return OtaInstallResult(
      installStarted: raw?['installStarted'] == true,
      openedSettings: raw?['openedSettings'] == true,
    );
  }

  static String _normalizeVersion(String raw) {
    final withoutPrefix = raw.startsWith('v') ? raw.substring(1) : raw;
    return withoutPrefix.split('+').first.trim();
  }

  static int _compareVersions(String a, String b) {
    final aParts = _parseVersion(a);
    final bParts = _parseVersion(b);
    final maxLength = aParts.length > bParts.length
        ? aParts.length
        : bParts.length;

    for (var i = 0; i < maxLength; i++) {
      final aValue = i < aParts.length ? aParts[i] : 0;
      final bValue = i < bParts.length ? bParts[i] : 0;
      if (aValue != bValue) return aValue.compareTo(bValue);
    }

    return 0;
  }

  static List<int> _parseVersion(String version) {
    final cleaned = _normalizeVersion(version);
    return cleaned
        .split(RegExp(r'[.\-]'))
        .map(
          (part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
        )
        .toList();
  }
}
