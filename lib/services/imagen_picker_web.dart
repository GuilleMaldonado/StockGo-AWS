import 'dart:typed_data';

import 'package:image_picker_for_web/image_picker_for_web.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';

Future<Uint8List?> seleccionarImagenProducto() async {
  // Usa el selector web directamente, incluso después de recargar una app en desarrollo.
  // La conversión se hace en Flutter para evitar depender del redimensionado HTML.
  final archivo = await ImagePickerPlugin().getImageFromSource(
    source: ImageSource.gallery,
  );
  if (archivo == null) return null;
  if (await archivo.length() > 20 * 1024 * 1024) {
    throw const FormatException('Selecciona una imagen de hasta 20 MB.');
  }
  return archivo.readAsBytes();
}
