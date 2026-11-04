import 'package:flutter/material.dart';

import '../models/ha_server.dart';
import '../services/ha_api.dart';
import '../services/store.dart';
import '../theme.dart';
import 'add_server_screen.dart';
import 'kiosk_screen.dart';
import 'server_screen.dart';

class _SrvStatus {
  final bool online;
  final int ms;
  final String version;
  const _SrvStatus(this.online, this.ms, this.version);
}

class ServersScreen extends StatefulWidget {
  const ServersScreen({super.key});

  @override
  State<ServersScreen> createState() => _ServersScreenState();
}

class _ServersScreenState extends State<ServersScreen> {
  List<HaServer> _servers = [];
  final Map<String, _SrvStatus> _status = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await Store.loadServers();
    if (!mounted) return;
    setState(() {
      _servers = list;
      _loading = false;
    });
    for (final s in list) {
      _check(s);
    }
    final auto = list.where((e) => e.autostart).toList();
    if (auto.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => KioskScreen(server: auto.first)),
        );
      });
    }
  }

  Future<void> _check(HaServer s) async {
    try {
      final sw = Stopwatch()..start();
      final m = await HaApi.manifest(s.url);
      sw.stop();
      if (!mounted) return;
      setState(() {
        _status[s.id] = _SrvStatus(
          true,
          sw.elapsedMilliseconds,
          (m['version'] as String?) ?? '',
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _status[s.id] = const _SrvStatus(false, 0, ''));
    }
  }

  Future<void> _save() => Store.saveServers(_servers);

  Future<void> _addServer() async {
    final created = await Navigator.of(context).push<HaServer>(
      MaterialPageRoute(builder: (_) => const AddServerScreen()),
    );
    if (created == null) return;
    setState(() => _servers.add(created));
    await _save();
    _check(created);
  }

  Future<void> _open(HaServer s) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ServerScreen(server: s)),
    );
    await _save();
    if (mounted) setState(() {});
  }

  Future<void> _rename(HaServer s) async {
    final ctrl = TextEditingController(text: s.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Название сервера'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    setState(() => s.name = name);
    await _save();
  }

  Future<void> _kioskSettings(HaServer s) async {
    var enabled = s.kiosk;
    var autoStart = s.autostart;
    final pinCtrl = TextEditingController(text: s.pin);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text('Режим киоска'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: enabled,
                title: const Text('Открывать на весь экран'),
                subtitle: const Text(
                  'Без панелей и кнопок — как табло на стене',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                onChanged: (v) => setLocal(() => enabled = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: autoStart,
                title: const Text('Запускать при старте'),
                subtitle: const Text(
                  'Приложение сразу откроет этот сервер в киоске',
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
                onChanged: (v) => setLocal(() => autoStart = v),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: pinCtrl,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: const InputDecoration(
                  labelText: 'PIN для выхода',
                  hintText: '0000',
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Долгое нажатие в левом верхнем углу — запрос PIN',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Готово'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    s.kiosk = enabled;
    s.autostart = autoStart;
    if (pinCtrl.text.trim().isNotEmpty) s.pin = pinCtrl.text.trim();
    await _save();
    if (mounted) setState(() {});
  }

  Future<void> _delete(HaServer s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Удалить сервер?'),
        content: Text('«${s.name}» пропадёт из списка. Настройки самого сервера не изменятся.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _servers.removeWhere((e) => e.id == s.id));
    await _save();
  }

  void _menu(HaServer s) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.fullscreen_rounded),
              title: const Text('Открыть в киоске'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ServerScreen(server: s, startKiosk: true),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Название'),
              onTap: () {
                Navigator.pop(ctx);
                _rename(s);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_brightness_rounded),
              title: const Text('Режим киоска и PIN'),
              onTap: () {
                Navigator.pop(ctx);
                _kioskSettings(s);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.red),
              title: const Text('Удалить', style: TextStyle(color: AppColors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _delete(s);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addServer,
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Сервер'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF101728), AppColors.bg],
          ),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            color: AppColors.accent,
            onRefresh: () async {
              for (final s in _servers) {
                _check(s);
              }
            },
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                    children: [
                      _header(),
                      const SizedBox(height: 24),
                      if (_servers.isEmpty) _empty() else ..._cards(),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(colors: [AppColors.accent, AppColors.violet]),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'S',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 14),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SATL', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 1)),
            Text('Ваши серверы', style: TextStyle(color: AppColors.muted, fontSize: 13)),
          ],
        ),
      ],
    );
  }

  List<Widget> _cards() {
    final out = <Widget>[];
    for (var i = 0; i < _servers.length; i++) {
      out.add(_card(_servers[i], i));
      out.add(const SizedBox(height: 14));
    }
    out.add(
      const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text(
          'Нажмите на карточку, чтобы открыть. Долгое нажатие — настройки сервера.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
      ),
    );
    return out;
  }

  Widget _card(HaServer s, int index) {
    final base = colorFromHex(s.color);
    final st = _status[s.id];
    final online = st?.online;
    return GestureDetector(
      onTap: () => _open(s),
      onLongPress: () => _menu(s),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [base, Color.lerp(base, const Color(0xFF7B4CFF), 0.55)!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: base.withValues(alpha: 0.28),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.home_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s.url.replaceFirst(RegExp(r'^https?://'), ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white70),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip(
                  online == null
                      ? 'Проверка…'
                      : online
                          ? (st!.ms > 0 ? 'Онлайн · ${st.ms} мс' : 'Онлайн')
                          : 'Недоступен',
                  online == null
                      ? Colors.white54
                      : online
                          ? AppColors.green
                          : AppColors.red,
                ),
                if ((st?.version ?? s.version).isNotEmpty)
                  _chip('HA ${st?.version ?? s.version}', Colors.white70),
                if (s.kiosk) _chip('Киоск', Colors.white70),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text, Color dot) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _empty() {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.accent.withValues(alpha: 0.25),
                  AppColors.violet.withValues(alpha: 0.15),
                ],
              ),
            ),
            child: const Icon(Icons.dns_rounded, size: 54, color: AppColors.accent),
          ),
          const SizedBox(height: 24),
          const Text(
            'Пока нет серверов',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Добавьте свой Home Assistant — понадобится\nадрес, логин и пароль.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _addServer,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Добавить сервер'),
          ),
        ],
      ),
    );
  }
}
