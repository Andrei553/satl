import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../models/ha_server.dart';
import '../services/ha_api.dart';
import '../services/store.dart';
import '../theme.dart';
import 'kiosk_screen.dart';

class ServerScreen extends StatefulWidget {
  final HaServer server;
  final bool startKiosk;
  const ServerScreen({super.key, required this.server, this.startKiosk = false});

  @override
  State<ServerScreen> createState() => _ServerScreenState();
}

class _ServerScreenState extends State<ServerScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  List<Map<String, dynamic>> _states = [];
  bool _loading = true;
  String? _error;
  int _latency = 0;

  HaServer get s => widget.server;

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.startKiosk) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openKiosk());
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final sw = Stopwatch()..start();
      final cfg = await HaApi.config(s);
      sw.stop();
      s.version = (cfg['version'] as String?) ?? s.version;
      final states = await HaApi.states(s);
      if (!mounted) return;
      setState(() {
        _states = states;
        _latency = sw.elapsedMilliseconds;
        _loading = false;
        _error = null;
      });
    } on HaException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Нет связи с сервером';
      });
    }
  }

  Future<void> _openKiosk() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => KioskScreen(server: s)),
    );
  }

  Future<void> _switchServer() async {
    final all = await Store.loadServers();
    if (!mounted) return;
    final picked = await showModalBottomSheet<HaServer>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Переключить сервер',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            ...all.map(
              (e) => ListTile(
                leading: Icon(
                  Icons.circle,
                  size: 12,
                  color: colorFromHex(e.color),
                ),
                title: Text(e.name),
                subtitle: Text(
                  e.url.replaceFirst(RegExp(r'^https?://'), ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: e.id == s.id ? const Icon(Icons.check_rounded) : null,
                onTap: () => Navigator.pop(ctx, e),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (picked == null || picked.id == s.id || !mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ServerScreen(server: picked)),
    );
  }

  String _injectScript() {
    final data = <String, dynamic>{
      'access_token': s.accessToken ?? '',
      'token_type': 'Bearer',
      'expires_in': 1800,
      'refresh_token': s.refreshToken ?? '',
      'hassUrl': s.url,
      'clientId': s.clientId,
      'expires': DateTime.now().millisecondsSinceEpoch + 1800 * 1000,
    };
    final js = jsonEncode(jsonEncode(data));
    return "try{localStorage.setItem('hassTokens',$js);}catch(e){}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text(
              s.url.replaceFirst(RegExp(r'^https?://'), ''),
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Сменить сервер',
            onPressed: _switchServer,
            icon: const Icon(Icons.swap_horiz_rounded),
          ),
          IconButton(
            tooltip: 'Режим киоска',
            onPressed: _openKiosk,
            icon: const Icon(Icons.fullscreen_rounded),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: AppColors.accent,
          labelColor: AppColors.text,
          unselectedLabelColor: AppColors.muted,
          tabs: const [
            Tab(text: 'Обзор'),
            Tab(text: 'Панель'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _overview(),
          _panel(),
        ],
      ),
    );
  }

  Widget _panel() {
    return InAppWebView(
      key: ValueKey('panel-${s.id}'),
      initialUrlRequest: URLRequest(url: WebUri(s.url)),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        useHybridComposition: true,
        supportZoom: false,
        mediaPlaybackRequiresUserGesture: false,
        transparentBackground: false,
      ),
      initialUserScripts: UnmodifiableListView<UserScript>([
        UserScript(
          source: _injectScript(),
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          forMainFrameOnly: true,
        ),
      ]),
    );
  }

  Widget _overview() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 56, color: AppColors.muted),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton(onPressed: _load, child: const Text('Повторить')),
            ],
          ),
        ),
      );
    }

    final tiles = _pickEntities();
    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _statsCard(),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Устройства',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              Text(
                '${tiles.length}',
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.35,
            ),
            itemCount: tiles.length,
            itemBuilder: (_, i) => _tile(tiles[i]),
          ),
        ],
      ),
    );
  }

  Widget _statsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            colorFromHex(s.color).withValues(alpha: 0.9),
            Color.lerp(colorFromHex(s.color), const Color(0xFF7B4CFF), 0.6)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _stat('Версия', s.version.isEmpty ? '—' : s.version),
              _stat('Отклик', _latency > 0 ? '$_latency мс' : '—'),
              _stat('Объектов', '${_states.length}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  /// Сколько плиток показывать с каждого типа устройств.
  static const _perDomain = {
    'light': 8,
    'switch': 8,
    'climate': 6,
    'cover': 4,
    'sensor': 8,
    'binary_sensor': 6,
  };

  /// Берёт объекты «понемногу от каждого типа», чтобы в обзоре были и свет,
  /// и розетки, и климат, и датчики. Недоступные и скрытые пропускает.
  List<Map<String, dynamic>> _pickEntities() {
    final byDomain = <String, List<Map<String, dynamic>>>{};
    for (final e in _states) {
      final id = (e['entity_id'] as String? ?? '');
      final domain = id.split('.').first;
      final limit = _perDomain[domain];
      if (limit == null) continue;
      final attrs = e['attributes'] as Map<String, dynamic>? ?? {};
      if (attrs['hidden_by'] != null || attrs['hidden'] == true) continue;
      final state = e['state'] as String? ?? '';
      if (state == 'unavailable' || state == 'unknown') continue;
      final bucket = byDomain.putIfAbsent(domain, () => []);
      if (bucket.length >= limit) continue;
      bucket.add(e);
    }
    final out = <Map<String, dynamic>>[];
    for (final domain in _perDomain.keys) {
      final bucket = byDomain[domain];
      if (bucket == null) continue;
      bucket.sort((a, b) => _friendly(a).compareTo(_friendly(b)));
      out.addAll(bucket);
    }
    return out;
  }

  String _friendly(Map<String, dynamic> e) {
    final attrs = e['attributes'] as Map<String, dynamic>? ?? {};
    return (attrs['friendly_name'] as String?) ?? (e['entity_id'] as String);
  }

  bool _controllable(String id) {
    final d = id.split('.').first;
    return d == 'light' || d == 'switch' || d == 'input_boolean';
  }

  Future<void> _toggle(Map<String, dynamic> e) async {
    final id = e['entity_id'] as String;
    final domain = id.split('.').first;
    final on = (e['state'] as String?) == 'on';
    try {
      await HaApi.callService(s, domain, on ? 'turn_off' : 'turn_on', id);
      await _load();
    } on HaException catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.message)));
    }
  }

  Widget _tile(Map<String, dynamic> e) {
    final id = e['entity_id'] as String;
    final domain = id.split('.').first;
    final attrs = e['attributes'] as Map<String, dynamic>? ?? {};
    final color = domainColor(domain);
    final state = (e['state'] as String?) ?? '—';
    final on = state == 'on';

    var value = _translateState(state);
    final unit = (attrs['unit_of_measurement'] as String?) ?? '';
    if (domain == 'sensor' && unit.isNotEmpty) value = '$state $unit';
    if (domain == 'climate') {
      final cur = attrs['current_temperature'];
      if (cur != null) value = '$cur°';
    }

    final icon = _iconFor(domain, attrs, on);

    return GestureDetector(
      onTap: _controllable(id) ? () => _toggle(e) : null,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: on ? color.withValues(alpha: 0.18) : AppColors.card,
          border: Border.all(
            color: on ? color.withValues(alpha: 0.55) : Colors.white.withValues(alpha: 0.04),
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: on ? 0.9 : 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: on ? Colors.white : color),
                ),
                const Spacer(),
                if (_controllable(id))
                  Icon(
                    on ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                    color: on ? color : AppColors.muted,
                    size: 26,
                  ),
              ],
            ),
            const Spacer(),
            Text(
              _friendly(e),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.2),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: on ? color : AppColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _translateState(String state) {
    switch (state) {
      case 'on':
        return 'Включено';
      case 'off':
        return 'Выключено';
      case 'unavailable':
        return 'Недоступно';
      case 'unknown':
        return 'Нет данных';
      default:
        return state;
    }
  }

  IconData _iconFor(String domain, Map<String, dynamic> attrs, bool on) {
    final dc = attrs['device_class'] as String?;
    if (domain == 'light') return on ? Icons.lightbulb_rounded : Icons.lightbulb_outline_rounded;
    if (domain == 'switch') return Icons.power_settings_new_rounded;
    if (domain == 'climate') return Icons.thermostat_rounded;
    if (domain == 'cover') return Icons.blinds_rounded;
    if (domain == 'binary_sensor') {
      if (dc == 'motion') return Icons.directions_run_rounded;
      if (dc == 'door' || dc == 'window') return Icons.sensor_door_rounded;
      if (dc == 'moisture') return Icons.water_drop_rounded;
      return Icons.sensors_rounded;
    }
    if (dc == 'temperature') return Icons.thermostat_rounded;
    if (dc == 'humidity') return Icons.water_drop_rounded;
    if (dc == 'battery') return Icons.battery_std_rounded;
    if (dc == 'power' || dc == 'energy') return Icons.bolt_rounded;
    return Icons.speed_rounded;
  }
}
