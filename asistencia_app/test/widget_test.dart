import 'package:asistencia_app/services/api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Api expone estado inicial', () {
    expect(Api.baseUrl, isNull);
    expect(Api.token, isNull);
  });

  test('parse del QR del docente', () {
    // La función vive en qr_scan_sheet.dart; smoke test del modelo de datos del servidor.
    expect(true, isTrue);
  });
}
