import 'package:flutter/material.dart';

class TagInfo {
  final String type;
  final String value;
  final String displayLabel;

  const TagInfo({
    required this.type,
    required this.value,
    required this.displayLabel,
  });

  factory TagInfo.parse(String label) {
    final parts = label.split(':');
    if (parts.length > 1) {
      final type = parts[0];
      final value = TagUtils.normalizeTagValue(parts.sublist(1).join(':'));
      return TagInfo(
        type: type,
        value: value,
        displayLabel: value.replaceAll('_', ' '),
      );
    }
    final value = TagUtils.normalizeTagValue(label);
    return TagInfo(
      type: 'tag',
      value: value,
      displayLabel: value.replaceAll('_', ' '),
    );
  }

  String get key => TagUtils.buildKey(type, value);
}

class TagUtils {
  static String buildKey(String type, String value) {
    final normalizedValue = normalizeTagValue(value);
    return type == 'tag' ? 'tag:$normalizedValue' : '$type:$normalizedValue';
  }

  static String displayName(String value) {
    return normalizeTagValue(value).replaceAll('_', ' ');
  }

  static String normalizeTagValue(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), '_');
  }

  static String normalizeTagLabel(String label) {
    final separator = label.indexOf(':');
    if (separator == -1) return normalizeTagValue(label);

    final type = label.substring(0, separator);
    final value = label.substring(separator + 1);
    return '$type:${normalizeTagValue(value)}';
  }

  static String normalizeQuery(String query) {
    return query
        .trim()
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .map(normalizeTagLabel)
        .join(' ');
  }

  static IconData iconFor(String type) {
    switch (type) {
      case 'female':
        return Icons.female_rounded;
      case 'male':
        return Icons.male_rounded;
      case 'artist':
        return Icons.brush_rounded;
      case 'series':
      case 'parody':
        return Icons.book_rounded;
      case 'character':
        return Icons.face_rounded;
      case 'group':
        return Icons.groups_rounded;
      case 'language':
        return Icons.translate_rounded;
      default:
        return Icons.label_rounded;
    }
  }

  static Color colorFor(String type, ColorScheme colorScheme) {
    switch (type) {
      case 'female':
        return Colors.pinkAccent;
      case 'male':
        return Colors.blueAccent;
      case 'recent':
        return colorScheme.secondary;
      default:
        return colorScheme.onSurfaceVariant;
    }
  }

  static Color backgroundFor(String type, ColorScheme colorScheme) {
    switch (type) {
      case 'female':
        return Colors.pinkAccent.withValues(alpha: 0.1);
      case 'male':
        return Colors.blueAccent.withValues(alpha: 0.1);
      default:
        return colorScheme.surfaceContainerHigh;
    }
  }
}
