import 'dart:typed_data';
import 'dart:ui' as ui;

Future<Uint8List> prepararImagenProducto(Uint8List bytes) async {
  if (bytes.isEmpty || bytes.length > 20 * 1024 * 1024) {
    throw const FormatException('Selecciona una imagen válida de hasta 20 MB.');
  }
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? imagen;
  try {
    buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    // Consulta las dimensiones del encabezado sin decodificar primero la foto completa.
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final mayor = descriptor.width > descriptor.height
        ? descriptor.width
        : descriptor.height;
    final escala = mayor > 1200 ? 1200 / mayor : 1.0;
    final ancho = (descriptor.width * escala).round().clamp(1, 1200);
    final alto = (descriptor.height * escala).round().clamp(1, 1200);
    codec = await descriptor.instantiateCodec(
      targetWidth: ancho,
      targetHeight: alto,
    );
    imagen = (await codec.getNextFrame()).image;
    final png = await imagen.toByteData(format: ui.ImageByteFormat.png);
    if (png == null) {
      throw const FormatException('No se pudo procesar esta imagen.');
    }
    final resultado = png.buffer.asUint8List(
      png.offsetInBytes,
      png.lengthInBytes,
    );
    if (resultado.length > 5 * 1024 * 1024) {
      throw const FormatException(
        'La imagen procesada supera 5 MB. Elige una fotografía de menor tamaño.',
      );
    }
    return resultado;
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException(
      'Este archivo no es una imagen compatible. Usa JPG, PNG, WebP o BMP.',
    );
  } finally {
    imagen?.dispose();
    codec?.dispose();
    descriptor?.dispose();
    buffer?.dispose();
  }
}
