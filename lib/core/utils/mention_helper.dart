import 'package:flutter/material.dart';

class MentionHelper {
  /// Returns the matching mention for a given grade based on cycle configuration.
  /// Grade should be on the same scale as the mention's note_min/note_max (usually 20 or 10).
  static Map<String, dynamic>? getMentionForGrade(
    double grade,
    List<Map<String, dynamic>> mentions,
  ) {
    if (mentions.isEmpty) return null;

    for (var mention in mentions) {
      final double min = (mention['note_min'] as num?)?.toDouble() ?? 0.0;
      final double max = (mention['note_max'] as num?)?.toDouble() ?? 20.0;

      if (grade >= min && grade <= max) {
        return mention;
      }
    }

    // If no exact match (sometimes rounding issues), find the closest one
    // or return the last one if it's below the lowest min
    return null;
  }

  /// Returns the color from hex string or a default color.
  static Color getMentionColor(String? colorHex) {
    if (colorHex == null || colorHex.isEmpty) return Colors.grey;
    try {
      if (colorHex.startsWith('#')) {
        return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
      }
      return Colors.grey;
    } catch (_) {
      return Colors.grey;
    }
  }

  /// Returns the appropriate icon data based on the icone name.
  static IconData getMentionIcon(String? iconName) {
    switch (iconName) {
      case 'excellent':
        return Icons.workspace_premium;
      case 'star':
        return Icons.stars;
      case 'thumb':
        return Icons.thumb_up;
      case 'medal':
        return Icons.military_tech;
      default:
        return Icons.stars;
    }
  }

  /// Removes emojis and other non-standard characters from a string.
  static String stripEmojis(String text) {
    // Basic regex to remove common emoji ranges.
    // This is not exhaustive but covers most common cases.
    return text
        .replaceAll(
          RegExp(
            r'[\u{1F600}-\u{1F64F}\u{1F300}-\u{1F5FF}\u{1F680}-\u{1F6FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{1F1E6}-\u{1F1FF}\u{1F900}-\u{1F9FF}\u{1F018}-\u{1F02B}\u{1F004}\u{1F0CF}\u{1F18E}\u{1F191}-\u{1F19A}\u{1F1E6}-\u{1F1FF}\u{1F201}\u{1F21A}\u{1F22F}\u{1F232}-\u{1F236}\u{1F238}-\u{1F23A}\u{1F250}\u{1F251}\u{1F300}-\u{1F320}\u{1F32D}-\u{1F335}\u{1F337}-\u{1F37C}\u{1F37E}-\u{1F393}\u{1F3A0}-\u{1F3CA}\u{1F3CF}-\u{1F3D3}\u{1F3E0}-\u{1F3F0}\u{1F3F4}\u{1F3F8}-\u{1F43E}\u{1F440}\u{1F442}-\u{1F4FC}\u{1F4FF}-\u{1F53D}\u{1F54B}-\u{1F54E}\u{1F550}-\u{1F567}\u{1F57A}\u{1F595}\u{1F596}\u{1F5A4}\u{1F5FB}-\u{1F64F}\u{1F680}-\u{1F6C5}\u{1F6CC}\u{1F6D0}-\u{1F6D2}\u{1F6EB}\u{1F6EC}\u{1F6F4}-\u{1F6F9}\u{1F910}-\u{1F93E}\u{1F940}-\u{1F970}\u{1F980}-\u{1F9E6}]',
            unicode: true,
          ),
          '',
        )
        .trim();
  }
}
