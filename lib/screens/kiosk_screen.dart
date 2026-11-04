import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../models/ha_server.dart';
import '../theme.dart';

class KioskScreen extends StatefulWidget {
  final HaServer server;
  const KioskScreen({super.key, required this.server});

  @override
  State<KioskScreen> createState() => _KioskScreenState();
}

class _KioskScreenState extends State<KioskScreen> {
  bool _allowLeave = false;

  HaServer get s => widget.server;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    });
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
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

  Future<void> _askPin() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Выход из киоска'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          decoration: const InputDecoration(labelText: 'PIN'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim() == s.pin),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      setState(() => _allowLeave = true);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowLeave,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _askPin();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            InAppWebView(
              key: ValueKey('kiosk-${s.id}'),
              initialUrlRequest: URLRequest(url: WebUri('${s.url}?kiosk')),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                domStorageEnabled: true,
                useHybridComposition: true,
                supportZoom: false,
                mediaPlaybackRequiresUserGesture: false,
                transparentBackground: false,
                useWideViewPort: true,
                loadWithOverviewMode: true,
              ),
              initialUserScripts: UnmodifiableListView<UserScript>([
                UserScript(
                  source: _injectScript(),
                  injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                  forMainFrameOnly: true,
                ),
              ]),
            ),
            Positioned(
              top: 0,
              left: 0,
              width: 64,
              height: 64,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onLongPress: _askPin,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
