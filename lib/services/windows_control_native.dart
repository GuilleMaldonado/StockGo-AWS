import 'dart:io';

import 'package:flutter/foundation.dart';

import '../data/stockgo_store.dart';
import '../network/windows_browser_control.dart';

WindowsBrowserControl? _control;
bool get admitePanelWindows => Platform.isWindows;

Future<void> abrirPanelWindows() async {
  if (!Platform.isWindows) return;
  await Process.start('rundll32.exe', [
    'url.dll,FileProtocolHandler',
    'http://127.0.0.1:8079/',
  ], mode: ProcessStartMode.detached);
}

Future<void> iniciarControlWindows(StockGoStore store) async {
  if (!Platform.isWindows) return;
  try {
    _control = WindowsBrowserControl(store: store);
    await _control!.iniciar();
  } catch (_) {
    debugPrint(
      'StockGo: el panel del navegador no pudo abrir el puerto local 8079.',
    );
  }
}
