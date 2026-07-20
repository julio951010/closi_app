import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TemaMapaService {
  static const _key = 'tema_mapa';
  static const List<String> temas = [
    'default',
    'newtron',
    'osmarender',
    'osmagray',
    'tronrender',
  ];
  static const Map<String, String> nombres = {
    'default': 'Clásico',
    'newtron': 'Newtron',
    'osmarender': 'Osmarender',
    'osmagray': 'Gris',
    'tronrender': 'Tron',
  };
  static final ValueNotifier<String> actual = ValueNotifier('default');

  static Future<void> inicializar() async {
    final prefs = await SharedPreferences.getInstance();
    actual.value = prefs.getString(_key) ?? 'default';
  }

  static Future<void> establecer(String tema) async {
    actual.value = tema;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, tema);
  }
}
