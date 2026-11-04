import 'package:flutter_test/flutter_test.dart';
import 'package:aplicacion_android/network/local_host.dart';

void main() {
  test(
    'HTTP local acepta IP privadas válidas y rechaza dominios similares',
    () {
      for (final host in [
        'localhost',
        'stockgo.local',
        '127.0.0.1',
        '10.0.0.2',
        '192.168.1.2',
        '172.16.0.1',
        '172.31.255.255',
      ]) {
        expect(esHostLocal(host), isTrue, reason: host);
      }
      for (final host in [
        '10.example.com',
        '192.168.example.com',
        '10.999.0.1',
        '172.32.0.1',
        '8.8.8.8',
        'example.com',
      ]) {
        expect(esHostLocal(host), isFalse, reason: host);
      }
    },
  );
}
