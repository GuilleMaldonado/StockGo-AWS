import 'package:flutter/material.dart';

import 'dart:async';

import 'services/windows_control.dart';

import 'theme/stockgo_theme.dart';
import 'widgets/stockgo_background.dart';

import 'data/platform/database_connection.dart';

import 'data/stockgo_store.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/cambiar_password_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = StockGoStore(factory: await crearDatabaseFactory());
  runApp(StockGoApp(store: store));
  unawaited(iniciarControlWindows(store));
}

class StockGoApp extends StatelessWidget {
  const StockGoApp({super.key, required this.store});
  final StockGoStore store;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'StockGo',
    debugShowCheckedModeBanner: false,
    theme: StockGoTheme.light,
    builder: (context, child) =>
        StockGoBackground(child: child ?? const SizedBox.shrink()),
    home: ListenableBuilder(
      listenable: store,
      builder: (context, child) => store.usuario == null
          ? LoginScreen(store: store)
          : store.usuario!.requiereCambioPassword
          ? CambiarPasswordScreen(store: store, obligatorio: true)
          : HomeScreen(store: store),
    ),
  );
}
