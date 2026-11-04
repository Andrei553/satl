import 'dart:convert';

class HaServer {
  String id;
  String name;
  String url;
  String? accessToken;
  String? refreshToken;
  int expiresAt;
  String clientId;
  bool kiosk;
  bool autostart;
  String pin;
  String color;
  String version;

  HaServer({
    required this.id,
    required this.name,
    required this.url,
    this.accessToken,
    this.refreshToken,
    this.expiresAt = 0,
    this.clientId = 'https://satl.app/android',
    this.kiosk = false,
    this.autostart = false,
    this.pin = '0000',
    this.color = '#5B8CFF',
    this.version = '',
  });

  bool get hasToken => (accessToken ?? '').isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'url': url,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'expiresAt': expiresAt,
        'clientId': clientId,
        'kiosk': kiosk,
        'autostart': autostart,
        'pin': pin,
        'color': color,
        'version': version,
      };

  factory HaServer.fromJson(Map<String, dynamic> j) => HaServer(
        id: j['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: j['name'] as String? ?? 'Сервер',
        url: j['url'] as String? ?? '',
        accessToken: j['accessToken'] as String?,
        refreshToken: j['refreshToken'] as String?,
        expiresAt: (j['expiresAt'] as num?)?.toInt() ?? 0,
        clientId: j['clientId'] as String? ?? 'https://satl.app/android',
        kiosk: j['kiosk'] as bool? ?? false,
        autostart: j['autostart'] as bool? ?? false,
        pin: j['pin'] as String? ?? '0000',
        color: j['color'] as String? ?? '#5B8CFF',
        version: j['version'] as String? ?? '',
      );

  String toJsonString() => jsonEncode(toJson());
}
