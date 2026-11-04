import 'dart:io';

import 'package:satl/models/ha_server.dart';
import 'package:satl/services/ha_api.dart';

/// Проверка полного входа ровно тем кодом, который использует приложение.
Future<void> main(List<String> args) async {
  final url = HaApi.normalizeUrl(args.isNotEmpty
      ? args[0]
      : Platform.environment['SATL_URL'] ?? '');
  final username = args.length > 1
      ? args[1]
      : Platform.environment['SATL_LOGIN'] ?? '';
  final password = args.length > 2
      ? args[2]
      : Platform.environment['SATL_PASS'] ?? '';

  stdout.writeln('url: $url');

  final manifest = await HaApi.manifest(url);
  stdout.writeln('manifest: ok (${manifest['name']})');

  final tokens = await HaApi.login(
    url: url,
    username: username,
    password: password,
  );
  stdout.writeln('login: ok (access ${tokens.accessToken.length} chars, '
      'expires ${tokens.expiresIn}s)');

  final server = HaServer(
    id: 'probe',
    name: '',
    url: url,
    accessToken: tokens.accessToken,
    refreshToken: tokens.refreshToken,
    expiresAt: DateTime.now().millisecondsSinceEpoch + tokens.expiresIn * 1000,
  );

  final cfg = await HaApi.config(server);
  stdout.writeln('config: ${cfg['location_name']} / HA ${cfg['version']}');

  final states = await HaApi.states(server);
  stdout.writeln('states: ${states.length}');

  final counts = <String, int>{};
  for (final s in states) {
    final domain = (s['entity_id'] as String).split('.').first;
    counts[domain] = (counts[domain] ?? 0) + 1;
  }
  final top = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  stdout.writeln('топ доменов: ${top.take(8).map((e) => '${e.key}=${e.value}').join(', ')}');

  // Проверяем, что запись состояния (включение света/розетки) доступна.
  final light = states.firstWhere(
    (s) => (s['entity_id'] as String).startsWith('light.'),
    orElse: () => <String, dynamic>{},
  );
  if (light.isNotEmpty) {
    final id = light['entity_id'] as String;
    stdout.writeln('свет: $id = ${light['state']}');
    await HaApi.callService(
      server,
      'light',
      light['state'] == 'on' ? 'turn_off' : 'turn_on',
      id,
    );
    final after = await HaApi.states(server);
    final now = after.firstWhere((s) => s['entity_id'] == id);
    stdout.writeln('переключение: ok, новое состояние ${now['state']}');
  }
}
