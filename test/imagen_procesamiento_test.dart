import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:aplicacion_android/services/imagen_producto.dart';

Future<Uint8List> imagenGrande() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, 4000, 3000),
    ui.Paint()..color = const ui.Color(0xFF137C66),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(4000, 3000);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Foto de 12 megapíxeles se reduce a 1200 px conservando proporción y se puede mostrar', () async {
    final original = await imagenGrande();
    final result = await prepararImagenProducto(original)
        .timeout(const Duration(seconds: 20));
    final codec = await ui.instantiateImageCodec(result);
    final frame = await codec.getNextFrame();
    try {
      expect(frame.image.width, 1200);
      expect(frame.image.height, 900);
      expect(result.length, lessThan(5 * 1024 * 1024));
    } finally {
      frame.image.dispose();
      codec.dispose();
    }
  });
  test('Archivo incorrecto termina con mensaje y no queda esperando', () async {
    await expectLater(
      prepararImagenProducto(Uint8List.fromList([1, 2, 3, 4]))
          .timeout(const Duration(seconds: 5)),
      throwsA(isA<FormatException>()),
    );
  });
  test('Archivo vacío se rechaza antes de decodificar', () async {
    await expectLater(
      prepararImagenProducto(Uint8List(0)),
      throwsA(isA<FormatException>()),
    );
  });
}
