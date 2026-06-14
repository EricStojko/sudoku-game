import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/difficulty.dart';
import '../models/leaderboard_entry.dart';

/// Handles all persistence operations for per-difficulty leaderboards.
///
/// All methods are static — this class is never instantiated.
class LeaderboardService {
  LeaderboardService._();

  static String _key(Difficulty difficulty) =>
      'leaderboard_${difficulty.name}';

  /// Returns entries for [difficulty] sorted by time (fastest first).
  static Future<List<LeaderboardEntry>> fetchEntries(
    Difficulty difficulty,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final records = prefs.getStringList(_key(difficulty)) ?? [];
      final entries = <LeaderboardEntry>[];
      for (final r in records) {
        try {
          entries.add(LeaderboardEntry.fromJson(jsonDecode(r)));
        } catch (_) {
          // Skip corrupted record
        }
      }
      return entries..sort((a, b) => a.timeInSeconds.compareTo(b.timeInSeconds));
    } catch (_) {
      return [];
    }
  }

  /// Returns `true` if [timeInSeconds] would place in the top 10 for
  /// [difficulty].
  static Future<bool> isTop10(
    Difficulty difficulty,
    int timeInSeconds,
  ) async {
    try {
      final entries = await fetchEntries(difficulty);
      if (entries.length < 10) return true;
      return timeInSeconds < entries.last.timeInSeconds;
    } catch (_) {
      return false;
    }
  }

  /// Saves a score for [difficulty]. Keeps only the top 10 entries.
  static Future<void> saveScore(
    Difficulty difficulty,
    String name,
    int timeInSeconds,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _key(difficulty);
      var entries = await fetchEntries(difficulty);

      entries.add(LeaderboardEntry(
        name,
        timeInSeconds,
        DateTime.now().toIso8601String().split('T').first,
      ));
      entries.sort((a, b) => a.timeInSeconds.compareTo(b.timeInSeconds));
      if (entries.length > 10) entries = entries.sublist(0, 10);

      await prefs.setStringList(
        key,
        entries.map((e) => jsonEncode(e.toJson())).toList(),
      );
    } catch (_) {
      // Gracefully swallow persistence failures in production
    }
  }
}
