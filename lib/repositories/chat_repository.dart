import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/chat_thread.dart';

class ChatRepository {
  static const _threadsKey = 'threadsJson';
  Future<List<ChatThread>> loadThreads() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_threadsKey);
    if (encoded == null) return [];
    try {
      return (jsonDecode(encoded) as List<dynamic>)
          .whereType<Map>()
          .map((item) => ChatThread.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } on FormatException {
      await prefs.remove(_threadsKey);
      return [];
    } on TypeError {
      await prefs.remove(_threadsKey);
      return [];
    }
  }

  Future<void> saveThreads(List<ChatThread> threads) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _threadsKey,
      jsonEncode(threads.map((t) => t.toJson()).toList()),
    );
  }
}
