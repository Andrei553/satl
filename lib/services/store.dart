import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/ha_server.dart';

class Store {
  static const _kServers = 'satl_servers_v1';

  static Future<List<HaServer>> loadServers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kServers);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => HaServer.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveServers(List<HaServer> servers) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kServers,
      jsonEncode(servers.map((e) => e.toJson()).toList()),
    );
  }
}
