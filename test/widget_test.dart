import 'package:flutter_test/flutter_test.dart';
import 'package:satl/services/ha_api.dart';

void main() {
  group('normalizeUrl', () {
    test('добавляет http для домашней сети', () {
      expect(HaApi.normalizeUrl('192.168.1.125:8123'), 'http://192.168.1.125:8123');
    });

    test('добавляет https для внешнего адреса', () {
      expect(HaApi.normalizeUrl('ha.example.com'), 'https://ha.example.com');
    });

    test('не трогает готовый адрес и убирает слэш', () {
      expect(HaApi.normalizeUrl('https://ha.example.com/'), 'https://ha.example.com');
    });

    test('убирает пробелы', () {
      expect(HaApi.normalizeUrl(' 192.168.1.2:8123 '), 'http://192.168.1.2:8123');
    });
  });
}
