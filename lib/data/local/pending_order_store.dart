import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/pending_order.dart';

/// Persists the offline order queue as JSON — mobile counterpart of
/// berdikari-web's `useLocalStorage('berdikari_pos_queue', ...)`.
class PendingOrderStore {
  static const _key = 'berdikari_pos_queue';

  Future<List<PendingOrder>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(PendingOrder.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<PendingOrder> orders) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode(orders.map((o) => o.toJson()).toList()),
      );
    } catch (_) {
      // No platform channel available (e.g. widget tests) — the in-memory
      // queue still works for the current session, just isn't persisted.
    }
  }
}
