import 'package:flutter/material.dart';

import 'screens/add_server_screen.dart';
import 'theme.dart';

/// Отдельная точка входа только для превью экрана добавления сервера.
void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: const AddServerScreen(),
  ));
}
