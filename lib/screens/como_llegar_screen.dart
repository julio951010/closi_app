import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  MethodChannel? _channel;
  int _zoomActual = 15;

  @override
  void initState() {
    super.initState();
    _loadUbicacion();
  }

  Future<void> _loadUbicacion() async {
    try {
      _ubicacion = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {});
        _channel?.invokeMethod('setMyLocation', {
          'lat': _ubicacion!.latitude,
          'lon': _ubicacion!.longitude,
        });
      }
    } catch (_) {}
  }

  void _acercar() {
    if (_zoomActual >= 20) return;
    setState(() => _zoomActual++);
    _channel?.invokeMethod('setZoom', {'zoom': _zoomActual});
  }

  void _alejar() {
    if (_zoomActual <= 3) return;
    setState(() => _zoomActual--);
    _channel?.invokeMethod('setZoom', {'zoom': _zoomActual});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.negocio.nombre, style: const TextStyle(fontSize: 16)),
      ),
      body: Stack(
        children: [
          MapaOffline(
            negocios: [widget.negocio],
            negocioSeleccionadoId: widget.negocio.id,
            centro: Coordenada(widget.negocio.lat, widget.negocio.lon),
            readOnly: true,
            onNegocioTap: (_) {},
            onNegocioDetalle: (_) {},
            onMapaCreado: (channel) {
              _channel = channel;
              channel.invokeMethod('selectBusiness', {'id': widget.negocio.id});
              if (_ubicacion != null) {
                channel.invokeMethod('setMyLocation', {
                  'lat': _ubicacion!.latitude,
                  'lon': _ubicacion!.longitude,
                });
              }
            },
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            right: 16,
            child: Column(
              children: [
                _BotonZoom(Icons.add_rounded, _acercar, _zoomActual < 20),
                const SizedBox(height: 2),
                _BotonZoom(Icons.remove_rounded, _alejar, _zoomActual > 3),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonZoom extends StatelessWidget {
  final IconData icono;
  final VoidCallback onTap;
  final bool activo;
  const _BotonZoom(this.icono, this.onTap, this.activo);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: activo ? onTap : null,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: activo ? 0.85 : 0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1),
        ),
        child: Icon(
          icono,
          color: (activo ? const Color(0xFF1245A8) : Theme.of(context).colorScheme.onSurface).withValues(alpha: activo ? 0.85 : 0.4),
          size: 22,
        ),
      ),
    );
  }
}
