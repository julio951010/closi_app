import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/negocio.dart';
import '../services/tema_mapa_service.dart';

class Coordenada {
  final double latitude;
  final double longitude;
  const Coordenada(this.latitude, this.longitude);
}

class MapaOffline extends StatefulWidget {
  final List<Negocio> negocios;
  final String? negocioSeleccionadoId;
  final Coordenada centro;
  final Function(Negocio) onNegocioTap;
  final Function(Negocio) onNegocioDetalle;
  final ValueChanged<Coordenada>? onMapTapped;
  final Function(MethodChannel)? onMapaCreado;
  final bool readOnly;
  final int zoom;

  const MapaOffline({
    super.key,
    required this.negocios,
    required this.negocioSeleccionadoId,
    required this.centro,
    required this.onNegocioTap,
    required this.onNegocioDetalle,
    this.onMapTapped,
    this.onMapaCreado,
    this.readOnly = false,
    this.zoom = 13,
  });

  @override
  State<MapaOffline> createState() => _MapaOfflineState();
}

class _MapaOfflineState extends State<MapaOffline> {
  MethodChannel? _channel;

  @override
  void initState() {
    super.initState();
    TemaMapaService.actual.addListener(_onTemaMapaChanged);
  }

  @override
  void dispose() {
    TemaMapaService.actual.removeListener(_onTemaMapaChanged);
    super.dispose();
  }

  void _onTemaMapaChanged() {
    _channel?.invokeMethod('setTheme', {'theme': TemaMapaService.actual.value});
  }

  Future<void> _sendMarkers() async {
    if (_channel == null || widget.negocios.isEmpty) return;
    final markers = <Map<String, dynamic>>[];
    for (final n in widget.negocios) {
      Uint8List? imgBytes;
      String? path;
      if (n.thumbnailLocal != null && File(n.thumbnailLocal!).existsSync()) {
        path = n.thumbnailLocal;
      } else if (n.fotos.isNotEmpty && !n.fotos.first.startsWith('http')) {
        path = n.fotos.first;
      }
      if (path != null) {
        try {
          final file = File(path);
          if (await file.exists()) imgBytes = await file.readAsBytes();
        } catch (_) {}
      }
      markers.add({
        'lat': n.lat,
        'lon': n.lon,
        'nombre': n.nombre,
        'id': n.id,
        'categoria': n.categoria,
        'imageBytes': imgBytes,
      });
    }
    _channel!.invokeMethod('setMarkers', {'markers': markers});
  }

  void _onPlatformViewCreated(int id) {
    _channel = MethodChannel('closi_app/vtm_map_$id');
    _channel!.setMethodCallHandler(_handleMethodCall);
    widget.onMapaCreado?.call(_channel!);
    _sendMarkers();
  }

  @override
  void didUpdateWidget(MapaOffline oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sendMarkers();
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onMapClicked') {
      final lat = call.arguments['lat'] as double;
      final lon = call.arguments['lon'] as double;
      widget.onMapTapped?.call(Coordenada(lat, lon));
    } else if (call.method == 'onMarkerTapped') {
      final id = call.arguments['id'] as String;
      try {
        final negocio = widget.negocios.firstWhere((n) => n.id == id);
        widget.onNegocioTap(negocio);
        widget.onNegocioDetalle(negocio);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return AndroidView(
      viewType: 'closi_app/vtm_map',
      onPlatformViewCreated: _onPlatformViewCreated,
      creationParams: {
        'lat': widget.centro.latitude,
        'lon': widget.centro.longitude,
        'zoom': widget.zoom,
        'readOnly': widget.readOnly,
        'theme': TemaMapaService.actual.value,
      },
      creationParamsCodec: const StandardMessageCodec(),
    );
  }
}