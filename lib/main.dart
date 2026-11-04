import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/servers_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const SatlApp());
}

class SatlApp extends StatelessWidget {
  const SatlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SATL',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const ServersScreen(),
    );
  }
}
