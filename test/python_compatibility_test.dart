import 'dart:convert';
import 'dart:io';

import 'package:aplicacion_android/data/stockgo_repository.dart';
import 'package:aplicacion_android/models/producto.dart';
import 'package:aplicacion_android/models/usuario.dart';
import 'package:aplicacion_android/models/venta.dart';
import 'package:aplicacion_android/network/codigo_negocio.dart';
import 'package:aplicacion_android/network/stockgo_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test(
    'Flutter v10 importa a Python y conserva cuentas, productos y ventas',
    () async {
      sqfliteFfiInit();
      final temp = await Directory.systemTemp.createTemp('stockgo_python_');
      final repo = StockGoRepository(factory: databaseFactoryFfi);
      final path = '${temp.path}/negocio.db';
      Process? process;
      StockGoApi? api;
      try {
        await repo.inicializar(ruta: path, crearUsuariosDemo: false);
        await repo.asignarNombreNegocio('Aceitera Flutter');
        await repo.crearPropietario(
          'propietario',
          'Universidad123!',
          nombres: 'Ana',
          apellidos: 'López',
        );
        await repo.iniciarSesion('propietario', 'Universidad123!');
        await repo.crearUsuario(
          'juan.perez',
          'Vendedor123!',
          nombres: 'Juan',
          apellidos: 'Pérez',
        );
        final id = await repo.guardarProducto(
          const Producto(
            nombre: 'Filtro',
            codigo: 'F-001',
            precio: 50,
            costo: 30,
            cantidad: 6,
            categoria: 'Filtro',
            ficha: {'numeroParte': 'ABC123', 'lote': 'L2026'},
          ),
        );
        final businessId = await repo.obtenerCodigoNegocio();
        await repo.registrarVenta([
          LineaVenta(productoId: id, cantidad: 1),
        ], 'flutter_venta_original_0001');
        await repo.cerrarBaseDeDatos();
        process = await Process.start(
          Platform.environment['STOCKGO_TEST_PYTHON'] ?? 'python',
          [
            '-u',
            'servidor_python/tests/fixture_server.py',
            '--import-source',
            path,
          ],
        );
        final errors = process.stderr.transform(utf8.decoder).join();
        final first = await process.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .first
            .timeout(const Duration(seconds: 25));
        final configuration = jsonDecode(first) as Map<String, dynamic>;
        final code = CodigoNegocio.leer(configuration['sg1'] as String);
        expect(code.identificador, businessId);
        api = StockGoApi(code.direccion)..codigoConexion = code.identificador;
        expect(
          (await api.pedir('POST', 'connect', {
            'codigo': businessId,
          }))['nombreNegocio'],
          'Aceitera Flutter',
        );
        var login = await api.pedir('POST', 'auth/login', {
          'usuario': 'propietario',
          'password': 'Universidad123!',
        });
        api.token = login['token'] as String;
        expect(
          Usuario.fromMap((login['usuario'] as Map).cast<String, Object?>())
              .puedeAdministrar,
          true,
        );
        final history = await api.pedir('GET', 'sales');
        expect((history['ventas'] as List).length, 1);
        expect(
          ((history['ventas'] as List).first as Map)['vendedor'],
          'Ana López',
        );
        login = await api.pedir('POST', 'auth/login', {
          'usuario': 'juan.perez',
          'password': 'Vendedor123!',
        });
        api.token = login['token'] as String;
        final products = await api.pedir('GET', 'products?q=F-001');
        final product = ((products['productos'] as List).single as Map)
            .cast<String, Object?>();
        expect(product['cantidad'], 5);
        expect(product.containsKey('costo'), false);
        // Igual que StockGoStore._leerProducto: el contrato usa bool y Base64.
        final model = Producto.fromMap({
          ...product,
          'activo': product['activo'] == true ? 1 : 0,
          'imagen': null,
        });
        expect(model.ficha['numeroParte'], 'ABC123');
        final sale = await api.pedir('POST', 'sales', {
          'solicitud': 'flutter_python_venta_0002',
          'lineas': [
            LineaVenta(
              productoId: id,
              cantidad: 2,
              precioEsperadoCentavos: 5000,
            ).toMap(),
          ],
        });
        final ticket = Venta.fromMap(
          (sale['venta'] as Map).cast<String, Object?>(),
        );
        expect(ticket.totalCentavos, 10000);
        expect(ticket.vendedor, 'Juan Pérez');
        expect(ticket.detalles.single.containsKey('costoCentavos'), false);
        await expectLater(
          api.pedir('POST', 'products', {}),
          throwsA(isA<StockGoException>()),
        );
        final vendorSales = await api.pedir('GET', 'sales');
        expect((vendorSales['ventas'] as List).length, 1);
        await api.salir();
        await process.stdin.close();
        expect(
          await process.exitCode.timeout(const Duration(seconds: 25)),
          0,
          reason: await errors,
        );
        process = null;
        // La copia original sigue conteniendo seis menos una unidades y una sola venta.
        final original = await databaseFactoryFfi.openDatabase(path);
        expect((await original.query('productos')).single['cantidad'], 5);
        expect((await original.query('ventas')).length, 1);
        await original.close();
      } finally {
        api?.dispose();
        if (process != null) {
          await process.stdin.close();
          await process.exitCode.timeout(
            const Duration(seconds: 25),
            onTimeout: () {
              process!.kill();
              return -1;
            },
          );
        }
        await repo.cerrarBaseDeDatos();
        await temp.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
