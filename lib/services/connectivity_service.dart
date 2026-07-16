import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Envuelve `connectivity_plus` para exponer un stream simple de
/// online/offline. Nota: connectivity_plus solo dice si hay una interfaz de
/// red activa (WiFi/datos), no si esa red realmente tiene salida a
/// internet — suficiente para decidir cuándo *intentar* sincronizar.
class ConnectivityService {
  static final Connectivity _connectivity = Connectivity();

  static Future<bool> hayConexion() async {
    final resultados = await _connectivity.checkConnectivity();
    return _algunaActiva(resultados);
  }

  /// Emite `true`/`false` cada vez que cambia el estado de conectividad.
  static Stream<bool> get cambios {
    return _connectivity.onConnectivityChanged.map(_algunaActiva);
  }

  static bool _algunaActiva(List<ConnectivityResult> resultados) {
    return resultados.any((r) => r != ConnectivityResult.none);
  }
}
