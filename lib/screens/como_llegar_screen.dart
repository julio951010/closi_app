import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/negocio.dart';
import '../widgets/mapa_offline.dart';

class ComoLlegarScreen extends StatefulWidget {
  final Negocio negocio;
  const ComoLlegarScreen({super.key, required this.negocio});

  @override
  State<ComoLlegarScreen> createState() => _ComoLlegarScreenState();
}

class _ComoLlegarScreenState extends State<ComoLlegarScreen> {
  Position? _ubicacion;

  @override
  void initState() {
    super.initState();
    _loadUbicacion();
  }

  Future<void> _loadUbicacion() async {
    try {
      _ubicacion = await Geolocator.getCurrentPosition();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.negocio.nombre, style: const TextStyle(fontSize: 16)),
      ),
      body: MapaOffline(
        negocios: [widget.negocio],
        negocioSeleccionadoId: widget.negocio.id,
        centro: Coordenada(widget.negocio.lat, widget.negocio.lon),
        readOnly: true,
        onNegocioTap: (_) {},
        onNegocioDetalle: (_) {},
        onMapaCreado: (channel) {
          channel.invokeMethod('selectBusiness', {'id': widget.negocio.id});
          if (_ubicacion != null) {
            channel.invokeMethod('setMyLocation', {
              'lat': _ubicacion!.latitude,
              'lon': _ubicacion!.longitude,
            });
          }
        },
      ),
    );
  }
}
