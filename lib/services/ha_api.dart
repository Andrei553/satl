import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ha_server.dart';

class HaException implements Exception {
  final String message;
  HaException(this.message);
  @override
  String toString() => message;
}

class AuthTokens {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  AuthTokens(this.accessToken, this.refreshToken, this.expiresIn);
}

class HaApi {
  static const clientId = 'https://satl.app/android';

  /// Приводит введённый адрес к нормальному виду.
  static String normalizeUrl(String input) {
    var s = input.trim();
    if (s.isEmpty) return s;
    s = s.replaceAll(' ', '');
    if (!s.contains('://')) {
      final host = s.split('/').first.split(':').first;
      final isLocal = host == 'localhost' ||
          host.startsWith('127.') ||
          host.startsWith('192.168.') ||
          host.startsWith('10.') ||
          host.endsWith('.local') ||
          RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(host);
      s = (isLocal ? 'http://' : 'https://') + s;
    }
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  static Future<Map<String, dynamic>> _json(http.Response r) async {
    if (r.statusCode >= 200 && r.statusCode < 300) {
      if (r.body.isEmpty) return <String, dynamic>{};
      final v = jsonDecode(utf8.decode(r.bodyBytes));
      if (v is Map<String, dynamic>) return v;
      return <String, dynamic>{'value': v};
    }
    if (r.statusCode == 401) {
      throw HaException('Неверный логин или пароль');
    }
    throw HaException('Сервер ответил ошибкой ${r.statusCode}');
  }

  static Future<Map<String, dynamic>> manifest(String url) async {
    final r = await http
        .get(Uri.parse('$url/manifest.json'))
        .timeout(const Duration(seconds: 8));
    return _json(r);
  }

  /// Вход по логину и паролю через штатный механизм Home Assistant.
  static Future<AuthTokens> login({
    required String url,
    required String username,
    required String password,
  }) async {
    final flow = await _startFlow(url);
    final flowId = flow['flow_id'] as String?;
    if (flowId == null) throw HaException('Сервер не поддерживает вход');

    final step = await http
        .post(
          Uri.parse('$url/auth/login_flow/$flowId'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'client_id': clientId,
            'username': username,
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 12));
    final result = await _json(step);

    if (result['type'] == 'create_entry') {
      final code = result['result'] as String;
      return _exchangeCode(url, code);
    }
    final errors = result['errors'];
    if (errors != null && errors.toString().isNotEmpty) {
      final text = errors.toString();
      if (text.contains('invalid_auth')) {
        throw HaException('Неверный логин или пароль');
      }
      if (text.contains('mfa') || text.contains('2fa')) {
        throw HaException('Включена двухфакторная защита. Добавьте сервер по токену.');
      }
      throw HaException('Не удалось войти: $text');
    }
    throw HaException('Не удалось войти. Проверьте логин и пароль.');
  }

  /// Начинает вход. Новые версии Home Assistant ждут handler списком,
  /// старые — строкой handler_name. Пробуем оба варианта.
  static Future<Map<String, dynamic>> _startFlow(String url) async {
    const endpoint = '/auth/login_flow';
    final modern = await http
        .post(
          Uri.parse('$url$endpoint'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'client_id': clientId,
            'handler': ['homeassistant', null],
            'redirect_uri': clientId,
          }),
        )
        .timeout(const Duration(seconds: 12));
    if (modern.statusCode == 200) return _json(modern);

    final legacy = await http
        .post(
          Uri.parse('$url$endpoint'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'client_id': clientId,
            'handler_name': 'Home Assistant Local',
            'redirect_uri': clientId,
          }),
        )
        .timeout(const Duration(seconds: 12));
    return _json(legacy);
  }

  static Future<AuthTokens> _exchangeCode(String url, String code) async {
    final r = await http.post(
      Uri.parse('$url/auth/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'client_id': clientId,
      },
    ).timeout(const Duration(seconds: 12));
    final j = await _json(r);
    final at = j['access_token'] as String?;
    final rt = j['refresh_token'] as String?;
    if (at == null || rt == null) throw HaException('Сервер не выдал токен');
    return AuthTokens(at, rt, (j['expires_in'] as num?)?.toInt() ?? 1800);
  }

  static Future<void> refresh(HaServer s) async {
    final rt = s.refreshToken;
    if (rt == null || rt.isEmpty) return;
    final r = await http.post(
      Uri.parse('${s.url}/auth/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': rt,
        'client_id': s.clientId,
      },
    ).timeout(const Duration(seconds: 12));
    final j = await _json(r);
    s.accessToken = j['access_token'] as String? ?? s.accessToken;
    s.refreshToken = j['refresh_token'] as String? ?? s.refreshToken;
    s.expiresAt = DateTime.now().millisecondsSinceEpoch +
        ((j['expires_in'] as num?)?.toInt() ?? 1800) * 1000;
  }

  static Future<void> _ensureToken(HaServer s) async {
    final expired = DateTime.now().millisecondsSinceEpoch > s.expiresAt - 60000;
    if ((s.accessToken ?? '').isEmpty || expired) {
      await refresh(s);
    }
  }

  static Future<http.Response> _authGet(HaServer s, String path) async {
    await _ensureToken(s);
    var r = await http.get(
      Uri.parse('${s.url}$path'),
      headers: {'Authorization': 'Bearer ${s.accessToken}'},
    ).timeout(const Duration(seconds: 15));
    if (r.statusCode == 401) {
      await refresh(s);
      r = await http.get(
        Uri.parse('${s.url}$path'),
        headers: {'Authorization': 'Bearer ${s.accessToken}'},
      ).timeout(const Duration(seconds: 15));
    }
    return r;
  }

  static Future<Map<String, dynamic>> config(HaServer s) async {
    final r = await _authGet(s, '/api/config');
    return _json(r);
  }

  static Future<List<Map<String, dynamic>>> states(HaServer s) async {
    final r = await _authGet(s, '/api/states');
    if (r.statusCode == 401) throw HaException('Сессия истекла, войдите заново');
    final v = jsonDecode(utf8.decode(r.bodyBytes));
    if (v is! List) throw HaException('Неожиданный ответ сервера');
    return v.cast<Map<String, dynamic>>();
  }

  static Future<void> callService(
    HaServer s,
    String domain,
    String service,
    String entityId,
  ) async {
    await _ensureToken(s);
    final r = await http.post(
      Uri.parse('${s.url}/api/services/$domain/$service'),
      headers: {
        'Authorization': 'Bearer ${s.accessToken}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'entity_id': entityId}),
    ).timeout(const Duration(seconds: 15));
    if (r.statusCode >= 300) {
      throw HaException('Не удалось выполнить команду (${r.statusCode})');
    }
  }

  static Future<int> latency(String url) async {
    final sw = Stopwatch()..start();
    await manifest(url);
    sw.stop();
    return sw.elapsedMilliseconds;
  }
}
