import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:aplicacion_android/data/stockgo_repository.dart';
import 'package:aplicacion_android/data/stockgo_store.dart';
import 'package:aplicacion_android/models/producto.dart';
import 'package:aplicacion_android/models/venta.dart';
import 'package:aplicacion_android/network/stockgo_lan_server.dart';
import 'package:aplicacion_android/network/codigo_negocio.dart';

void main() {
  setUpAll(sqfliteFfiInit);
  test(
    'Ventas por red: stock atómico, lotes, permisos, historial y reintentos',
    () async {
      final dir = await Directory.systemTemp.createTemp('stockgo_ventas_');
      final repo = StockGoRepository(factory: databaseFactoryFfi);
      final server = StockGoLanServer(
        factory: databaseFactoryFfi,
        ruta: '${dir.path}/ventas.db',
      );
      final clients = List.generate(
        4,
        (_) => StockGoStore(factory: databaseFactoryFfi),
      );
      try {
        await repo.inicializar(ruta: server.ruta, crearUsuariosDemo: false);
        await repo.crearPropietario(
          'dueno',
          'Admin123!',
          nombres: 'Ana',
          apellidos: 'Perez',
        );
        await repo.iniciarSesion('dueno', 'Admin123!');
        await repo.crearUsuario(
          'equipo',
          'Vendedor123!',
          nombres: 'Ana',
          apellidos: 'Perez',
        );
        final aceite = await repo.guardarProducto(
          const Producto(
            nombre: 'Aceite',
            codigo: 'ACE-LOTE-A',
            precio: 10.25,
            costo: 7,
            cantidad: 3,
            categoria: 'Lubricante',
            ficha: {'lote': 'FAB-A', 'unidadVenta': 'Botella'},
          ),
        );
        final filtro = await repo.guardarProducto(
          const Producto(
            nombre: 'Filtro',
            codigo: 'F-1',
            precio: 8,
            costo: 5,
            cantidad: 1,
          ),
        );
        final vencido = await repo.guardarProducto(
          const Producto(
            nombre: 'Aceite vencido',
            codigo: 'OLD',
            precio: 10,
            cantidad: 1,
            categoria: 'Lubricante',
            ficha: {'lote': 'OLD-A', 'vencimiento': '2000-01-01'},
          ),
        );
        await expectLater(
          repo.guardarProducto(
            const Producto(
              nombre: 'Pérdida',
              codigo: 'NO',
              precio: 5,
              costo: 8,
              cantidad: 1,
            ),
          ),
          throwsA(isA<StockGoException>()),
        );
        await expectLater(
          repo.guardarProducto(
            const Producto(
              nombre: 'Fracción',
              codigo: 'NO',
              precio: 1.234,
              cantidad: 1,
            ),
          ),
          throwsA(isA<StockGoException>()),
        );
        await expectLater(
          repo.guardarProducto(
            Producto(
              id: aceite,
              nombre: 'Aceite',
              codigo: 'ACE-LOTE-A',
              precio: 10.25,
              costo: 7,
              cantidad: 3,
              categoria: 'Lubricante',
              ficha: const {'lote': 'FAB-B'},
            ),
          ),
          throwsA(isA<StockGoException>()),
        );
        await server.iniciar(port: 0, address: InternetAddress.loopbackIPv4);
        final codigo = CodigoNegocio(
          'http://127.0.0.1:${server.puerto}',
          server.codigoConexion,
        ).codificar();
        final admin = clients[0],
            vendedor = clients[1],
            segundo = clients[2],
            invitado = clients[3];
        await admin.entrarConCodigo(codigo, 'dueno', 'Admin123!');
        await vendedor.entrarConCodigo(codigo, 'equipo', 'Vendedor123!');
        await segundo.entrarConCodigo(codigo, 'equipo', 'Vendedor123!');
        await invitado.conectarConCodigo(codigo);
        await invitado.entrarInvitado();
        await expectLater(
          vendedor.registrarVenta([
            LineaVenta(
              productoId: aceite,
              cantidad: 1,
              precioEsperadoCentavos: 999,
            ),
          ], 'price_changed_request'),
          throwsA(isA<StockGoException>()),
        );
        expect((await repo.obtenerProductoPorId(aceite))!.cantidad, 3);
        await expectLater(
          invitado.registrarVenta([
            LineaVenta(productoId: aceite, cantidad: 1),
          ], 'guest_request_12345'),
          throwsA(isA<StockGoException>()),
        );
        await expectLater(
          invitado.listarVentas(),
          throwsA(isA<StockGoException>()),
        );
        await expectLater(
          vendedor.registrarVenta([
            LineaVenta(productoId: aceite, cantidad: 1),
            LineaVenta(productoId: filtro, cantidad: 2),
          ], 'rollback_request_12345'),
          throwsA(isA<StockGoException>()),
        );
        expect((await repo.obtenerProductoPorId(aceite))!.cantidad, 3);
        expect(await admin.listarVentas(), isEmpty);
        await expectLater(
          vendedor.registrarVenta([
            LineaVenta(productoId: vencido, cantidad: 1),
          ], 'expired_request_12345'),
          throwsA(isA<StockGoException>()),
        );
        await expectLater(
          vendedor.registrarVenta([
            LineaVenta(productoId: aceite, cantidad: 0),
          ], 'zero_request_12345'),
          throwsA(isA<StockGoException>()),
        );
        final lineas = [LineaVenta(productoId: aceite, cantidad: 2)];
        final venta = await vendedor.registrarVenta(
          lineas,
          'same_request_12345',
        );
        expect(venta.totalCentavos, 2050);
        expect(venta.vendedor, 'Ana Perez');
        expect(venta.codigoVendedor, startsWith('VD-'));
        expect(venta.detalles.single['lote'], 'FAB-A');
        expect(
          (await vendedor.registrarVenta(lineas, 'same_request_12345')).id,
          venta.id,
        );
        await expectLater(
          vendedor.registrarVenta([
            LineaVenta(productoId: aceite, cantidad: 1),
          ], 'same_request_12345'),
          throwsA(isA<StockGoException>()),
        );
        expect((await repo.obtenerProductoPorId(aceite))!.cantidad, 1);
        final resultados = await Future.wait(
          [vendedor, segundo].asMap().entries.map((e) async {
            try {
              await e.value.registrarVenta([
                LineaVenta(productoId: aceite, cantidad: 1),
              ], 'concurrent_request_${e.key}');
              return true;
            } on StockGoException {
              return false;
            }
          }),
        );
        expect(resultados.where((r) => r).length, 1);
        expect((await repo.obtenerProductoPorId(aceite))!.cantidad, 0);
        await repo.desactivarProducto(aceite);
        final historial = await admin.listarVentas();
        expect(historial.length, 2);
        expect(
          historial.every((v) => v.detalles.single['lote'] == 'FAB-A'),
          isTrue,
        );
        expect((await vendedor.listarVentas()).length, 2);
        final productosExtra = <int>[];
        for (var i = 0; i < 2; i++) {
          productosExtra.add(
            await repo.guardarProducto(
              Producto(
                nombre: 'Repuesto extra',
                codigo: 'EXTRA-$i',
                precio: 4,
                costo: 2,
                cantidad: 3,
              ),
            ),
          );
        }
        final cuenta = await vendedor.registrarVenta([
          LineaVenta(productoId: productosExtra[0], cantidad: 2),
          LineaVenta(productoId: productosExtra[1], cantidad: 1),
        ], 'multi_productos_12345');
        expect(cuenta.detalles.length, 2);
        expect(cuenta.totalCentavos, 1200);
        expect(
          (await repo.obtenerProductoPorId(productosExtra[0]))!.cantidad,
          1,
        );
        expect(
          (await repo.obtenerProductoPorId(productosExtra[1]))!.cantidad,
          2,
        );
        await admin.registrarVenta([
          LineaVenta(productoId: filtro, cantidad: 1),
        ], 'admin_request_12345');
        expect((await admin.listarVentas()).length, 4);
        expect((await vendedor.listarVentas()).length, 3);
      } finally {
        for (final client in clients) {
          client.dispose();
        }
        await server.detener();
        await repo.cerrarBaseDeDatos();
        await dir.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
