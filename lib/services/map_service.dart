import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class MapService {
  static const String _assetPath = 'assets/maps/cuba.map';
  static const String _fileName = 'cuba.map';
  static String? _cachedPath;

  static Future<String> getMapPath() async {
    if (_cachedPath != null && File(_cachedPath!).existsSync()) {
      return _cachedPath!;
    }

    final directory = await getApplicationDocumentsDirectory();
    final mapDir = Directory('${directory.path}/closi_maps');

    if (!await mapDir.exists()) {
      await mapDir.create(recursive: true);
    }

    final mapFile = File('${mapDir.path}/$_fileName');

    if (!await mapFile.exists()) {
      final byteData = await rootBundle.load(_assetPath);
      await mapFile.writeAsBytes(byteData.buffer.asUint8List());
    }

    _cachedPath = mapFile.path;
    return _cachedPath!;
  }
}