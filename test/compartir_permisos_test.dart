import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:aplicacion_android/data/stockgo_store.dart';

void main() {
  test('Compartir exige administrador local y negocio configurado', () async {
    sqfliteFfiInit();
    final store = StockGoStore(factory: databaseFactoryFfi);
    await store.inicializar(ruta: inMemoryDatabasePath);
    try {
      await expectLater(
        store.iniciarServidor(),
        throwsA(isA<StockGoException>()),
      );
      store.entrarComoInvitado();
      await expectLater(
        store.iniciarServidor(),
        throwsA(isA<StockGoException>()),
      );
      store.cerrarSesion();
      await store.iniciarSesion('vendedor', 'Vendedor123!');
      await expectLater(
        store.iniciarServidor(),
        throwsA(isA<StockGoException>()),
      );
      store.cerrarSesion();
      await store.iniciarSesion('admin', 'Admin123!');
      await expectLater(
        store.iniciarServidor(),
        throwsA(isA<StockGoException>()),
      );
      expect(store.servidorActivo, isFalse);
    } finally {
      store.dispose();
      await store.cerrarBaseDeDatos();
    }
  });
}
