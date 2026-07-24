import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:quiz/core/api/api_config.dart';
import 'package:quiz/core/model/leaderboard_entry.dart';

class LeaderboardVm extends ChangeNotifier {
  static const int topCount = 15;

  bool isLoading = false;
  String? errorMessage;
  List<LeaderboardEntry> entries = [];

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await http.get(
        Uri.parse('${ApiConfig.httpBase}/leaderboard?limit=$topCount'),
      );

      if (result.statusCode == 200) {
        final data = jsonDecode(result.body) as Map<String, dynamic>;
        final rawEntries = data['leaderboard'] as List<dynamic>? ?? [];
        entries = rawEntries
            .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
            .toList();
        errorMessage = null;
      } else {
        errorMessage = 'Failed to load leaderboard (${result.statusCode})';
      }
    } catch (e) {
      errorMessage = 'Network error: ${e.toString()}';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
