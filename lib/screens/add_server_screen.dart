import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/ha_server.dart';
import '../services/ha_api.dart';
import '../theme.dart';

class AddServerScreen extends StatefulWidget {
  const AddServerScreen({super.key});

  @override
  State<AddServerScreen> createState() => _AddServerScreenState();
}

class _AddServerScreenState extends State<AddServerScreen> {
  final _url = TextEditingController();
  final _login = TextEditingController();
  final _password = TextEditingController();
  final _token = TextEditingController();
  bool _advanced = false;
  bool _busy = false;
  String? _error;
  String _step = '';

  @override
  void dispose() {
    _url.dispose();
    _login.dispose();
    _password.dispose();
    _token.dispose();
    super.dispose();
  }

  void _setError(String text) {
    if (!mounted) return;
    setState(() {
      _error = text;
      _busy = false;
      _step = '';
    });
  }

  Future<void> _connect() async {
    FocusScope.of(context).unfocus();
    final url = HaApi.normalizeUrl(_url.text);
    if (url.isEmpty || !url.contains('.')) {
      _setError('Укажите адрес сервера, например 192.168.1.125:8123');
      return;
    }
    final useToken = _advanced && _token.text.trim().isNotEmpty;
    if (!useToken && (_login.text.trim().isEmpty || _password.text.isEmpty)) {
      _setError('Введите логин и пароль от Home Assistant');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _step = 'Проверяем адрес…';
    });

    try {
      final manifest = await HaApi.manifest(url);
      if (!mounted) return;
      setState(() => _step = useToken ? 'Проверяем токен…' : 'Входим…');

      String? access;
      String? refresh;
      var expiresAt = 0;

      if (useToken) {
        access = _token.text.trim();
        final r = await http.get(
          Uri.parse('$url/api/config'),
          headers: {'Authorization': 'Bearer $access'},
        ).timeout(const Duration(seconds: 12));
        if (r.statusCode == 401) {
          _setError('Токен не подошёл. Скопируйте его ещё раз в профиле Home Assistant.');
          return;
        }
        expiresAt = DateTime.now().millisecondsSinceEpoch + 315360000000;
      } else {
        final tokens = await HaApi.login(
          url: url,
          username: _login.text.trim(),
          password: _password.text,
        );
        access = tokens.accessToken;
        refresh = tokens.refreshToken;
        expiresAt = DateTime.now().millisecondsSinceEpoch + tokens.expiresIn * 1000;
      }

      if (!mounted) return;
      setState(() => _step = 'Загружаем настройки…');
      final tmp = HaServer(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: '',
        url: url,
        accessToken: access,
        refreshToken: refresh,
        expiresAt: expiresAt,
      );
      var name = (manifest['name'] as String?) ?? '';
      var version = (manifest['version'] as String?) ?? '';
      try {
        final cfg = await HaApi.config(tmp);
        name = (cfg['location_name'] as String?) ?? name;
        version = (cfg['version'] as String?) ?? version;
      } catch (_) {}

      tmp
        ..name = name.isEmpty ? 'Home Assistant' : name
        ..version = version
        ..color = _randomHex();

      if (!mounted) return;
      Navigator.of(context).pop(tmp);
    } on HaException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('Не удалось подключиться. Проверьте адрес и что сервер доступен.');
    }
  }

  String _randomHex() {
    const palette = [
      '#5B8CFF', '#38D39F', '#FF8A5B', '#A77BFF', '#43D6E8', '#FFB44C'
    ];
    return palette[DateTime.now().millisecondsSinceEpoch % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Новый сервер')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF101728), AppColors.bg],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              const Text(
                'Подключение',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Три поля — и готово. Пароль нигде не сохраняется, '
                'приложение получает только ключ доступа.',
                style: TextStyle(color: AppColors.muted, height: 1.45),
              ),
              const SizedBox(height: 22),
              TextField(
                controller: _url,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Адрес сервера',
                  hintText: '192.168.1.125:8123',
                  prefixIcon: Icon(Icons.link_rounded),
                ),
              ),
              const SizedBox(height: 12),
              if (!_advanced) ...[
                TextField(
                  controller: _login,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Логин',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Пароль',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                ),
              ] else ...[
                TextField(
                  controller: _token,
                  autocorrect: false,
                  maxLines: 3,
                  minLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Долгоживущий токен',
                    hintText: 'eyJ0eXAiOiJKV1Qi…',
                    prefixIcon: Icon(Icons.key_rounded),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Профиль → Безопасность → Долгоживущие токены → Создать',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _advanced = !_advanced),
                  icon: Icon(
                    _advanced ? Icons.person_outline_rounded : Icons.key_rounded,
                    size: 18,
                  ),
                  label: Text(
                    _advanced ? 'Войти по логину и паролю' : 'У меня есть токен',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.red.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.red),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppColors.red, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _busy ? null : _connect,
                child: _busy
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 12),
                          Text(_step),
                        ],
                      )
                    : const Text('Подключить'),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Где взять адрес',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Дома это http://192.168.1.125:8123. Снаружи — адрес, '
                      'по которому вы открываете Home Assistant в браузере.',
                      style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
