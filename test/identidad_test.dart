import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:aplicacion_android/data/stockgo_repository.dart';
import 'package:aplicacion_android/models/usuario.dart';

void main() {
  test(
    'Nombres sin números, vendedor identificado y código interno estable',
    () async {
      sqfliteFfiInit();
      final repo = StockGoRepository(factory: databaseFactoryFfi);
      try {
        await repo.inicializar(ruta: inMemoryDatabasePath);
        await repo.iniciarSesion('admin', 'Admin123!');
        await expectLater(
          repo.crearUsuario(
            'ana.perez',
            'ClaveSegura123!',
            nombres: 'Ana123',
            apellidos: 'Perez',
          ),
          throwsA(isA<StockGoException>()),
        );
        await expectLater(
          repo.crearUsuario(
            'ana123',
            'ClaveSegura123!',
            nombres: 'Ana',
            apellidos: 'Perez',
          ),
          throwsA(isA<StockGoException>()),
        );
        await repo.crearUsuario(
          'ana.perez',
          'ClaveSegura123!',
          nombres: 'Ana María',
          apellidos: 'Pérez López',
        );
        final persona = (await repo.listarUsuarios()).singleWhere(
          (u) => u.nombre == 'ana.perez',
        );
        expect(persona.nombreCompleto, 'Ana María Pérez López');
        expect(persona.codigoInterno, startsWith('VD-'));
        final codigo = persona.codigoInterno;
        await repo.iniciarSesion('ana.perez', 'ClaveSegura123!');
        await repo.completarPerfil('Ana', 'Pérez');
        expect(repo.usuario!.codigoInterno, codigo);
        expect(repo.usuario!.puedeVender, isTrue);
        expect(Usuario.validarNombre('Juan\\Perez'), isNotNull);
        expect(Usuario.validarNombre("O’Connor"), isNull);
      } finally {
        await repo.cerrarBaseDeDatos();
      }
    },
  );
}
