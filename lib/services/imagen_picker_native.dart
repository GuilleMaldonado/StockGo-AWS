import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:image_picker_android/image_picker_android.dart';
import 'package:image_picker_ios/image_picker_ios.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

Future<Uint8List?> seleccionarImagenProducto() async {
  if (Platform.isWindows) {
    // Diálogo nativo de archivos; PowerShell se ejecuta oculto, sin una terminal para el usuario.
    final result = await Process.run(
      'powershell.exe',
      [
        '-NoProfile',
        '-STA',
        '-WindowStyle',
        'Hidden',
        '-Command',
        r'''
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
Add-Type -AssemblyName System.Windows.Forms
$dialog = [System.Windows.Forms.OpenFileDialog]::new()
$dialog.Title = 'Seleccionar imagen del producto'
$dialog.Filter = 'Imagenes (*.jpg;*.jpeg;*.png;*.webp;*.bmp)|*.jpg;*.jpeg;*.png;*.webp;*.bmp'
$dialog.Multiselect = $false
try {
  if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { [Console]::Write($dialog.FileName) }
} finally { $dialog.Dispose() }
''',
      ],
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    if (result.exitCode != 0) {
      throw const FormatException(
        'No se pudo abrir el selector de archivos de Windows.',
      );
    }
    final path = (result.stdout as String).trim();
    if (path.isEmpty) return null;
    final file = File(path);
    if (await file.length() > 20 * 1024 * 1024) {
      throw const FormatException('Selecciona una imagen de hasta 20 MB.');
    }
    return file.readAsBytes();
  }
  final ImagePickerPlatform picker = Platform.isAndroid
      ? ImagePickerAndroid()
      : Platform.isIOS
      ? ImagePickerIOS()
      : ImagePickerPlatform.instance;
  final archivo = await picker.getImageFromSource(
    source: ImageSource.gallery,
    options: ImagePickerOptions(
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    ),
  );
  if (archivo == null) return null;
  if (await archivo.length() > 20 * 1024 * 1024) {
    throw const FormatException('Selecciona una imagen de hasta 20 MB.');
  }
  return archivo.readAsBytes();
}
