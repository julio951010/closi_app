import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gestiona el radio de búsqueda (en km) configurado por el usuario en
/// Configuración → Radio de búsqueda. Se persiste en SharedPreferences y se
/// expone como [ValueNotifier] para que cualquier pantalla (inicio, mapa,
/// buscar) reaccione en cuanto el usuario lo cambie, igual que [TemaService]
/// hace con el tema.
class RadioBusquedaService {
  static const _key = 'radio_busqueda_km';
  static const double defecto = 5.0;
  static const double minimo = 1.0;
  static const double maximo = 20.0;

  static final ValueNotifier<double> radioKm = ValueNotifier(defecto);

  static Future<void> inicializar() async {
    final prefs = await SharedPreferences.getInstance();
    final valor = prefs.getDouble(_key) ?? defecto;
    radioKm.value = valor.clamp(minimo, maximo);
  }

  static Future<void> establecer(double nuevo) async {
    final valor = nuevo.clamp(minimo, maximo);
    radioKm.value = valor;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key, valor);
  }
}
