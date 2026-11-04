import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:satl/main.dart';

void main() {
  testWidgets('главный экран запускается и показывает пустое состояние',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const SatlApp());
    await tester.pumpAndSettle();

    expect(find.text('SATL'), findsOneWidget);
    expect(find.text('Пока нет серверов'), findsOneWidget);
    expect(find.text('Добавить сервер'), findsOneWidget);
  });

  testWidgets('открывается форма добавления сервера', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const SatlApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Добавить сервер'));
    await tester.pumpAndSettle();

    expect(find.text('Новый сервер'), findsOneWidget);
    expect(find.text('Адрес сервера'), findsOneWidget);
    expect(find.text('Логин'), findsOneWidget);
    expect(find.text('Пароль'), findsOneWidget);
    expect(find.text('Подключить'), findsOneWidget);
  });
}
