import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TemaService {
  static const _key = 'tema_app';
  static final ValueNotifier<ThemeMode> modo = ValueNotifier(ThemeMode.light);

  static Future<void> inicializar() async {
    final prefs = await SharedPreferences.getInstance();
    final valor = prefs.getInt(_key) ?? 0;
    modo.value = _fromInt(valor);
  }

  static Future<void> establecer(ThemeMode nuevo) async {
    modo.value = nuevo;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, _toInt(nuevo));
  }

  static int _toInt(ThemeMode m) {
    if (m == ThemeMode.system) return 0;
    if (m == ThemeMode.dark) return 2;
    return 1;
  }

  static ThemeMode _fromInt(int i) {
    if (i == 1) return ThemeMode.light;
    if (i == 2) return ThemeMode.dark;
    return ThemeMode.system;
  }

  static String nombre(ThemeMode m) => switch (m) {
    ThemeMode.system => 'Sistema',
    ThemeMode.light => 'Claro',
    ThemeMode.dark => 'Oscuro',
  };
}
