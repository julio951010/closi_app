import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/mapa_offline.dart';

class SeleccionarUbicacionScreen extends StatefulWidget {
  final double latInicial;
  final double lonInicial;

  const SeleccionarUbicacionScreen({
    super.key,
    this.latInicial = 23.113592,
    this.lonInicial = -82.366592,
  });

  @override
  State<SeleccionarUbicacionScreen> createState() => _SeleccionarUbicacionScreenState();
}

class _SeleccionarUbicacionScreenState extends State<SeleccionarUbicacionScreen> {
  double _lat = 23.113592;
  double _lon = -82.366592;
  bool _pinColocado = false;
  bool _cargando = false;
  int _zoomActual = 13;
  MethodChannel? _channel;

  @override
  void initState() {
    super.initState();
    _lat = widget.latInicial;
    _lon = widget.lonInicial;
  }

  void _onMapaCreado(MethodChannel channel) {
    _channel = channel;
    channel.invokeMethod('placePin', {'lat': _lat, 'lon': _lon});
    channel.invokeMethod('setCenter', {'lat': _lat, 'lon': _lon});
    _pinColocado = true;
  }

  Future<void> _colocarPinEnMapa() async {
    if (_channel == null) return;
    try {
      await _channel!.invokeMethod('placePin', {'lat': _lat, 'lon': _lon});
      await _channel!.invokeMethod('setCenter', {'lat': _lat, 'lon': _lon});
    } catch (_) {}
  }

  void _onMapTapped(Coordenada c) {
    setState(() {
      _lat = c.latitude;
      _lon = c.longitude;
      _pinColocado = true;
    });
    _channel?.invokeMethod('placePin', {'lat': _lat, 'lon': _lon});
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

  Future<void> _confirmar() async {
    if (!_pinColocado) return;
    setState(() => _cargando = true);
    Navigator.pop(context, Coordenada(_lat, _lon));
  }

  void _usarCoordenadasManuales() {
    final latCtrl = TextEditingController(text: _lat.toStringAsFixed(6));
    final lonCtrl = TextEditingController(text: _lon.toStringAsFixed(6));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Coordenadas manuales'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: latCtrl,
              decoration: const InputDecoration(labelText: 'Latitud'),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: lonCtrl,
              decoration: const InputDecoration(labelText: 'Longitud'),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final lat = double.tryParse(latCtrl.text);
              final lon = double.tryParse(lonCtrl.text);
              if (lat == null || lon == null) return;
              setState(() { _lat = lat; _lon = lon; _pinColocado = true; });
              Navigator.pop(ctx);
              _colocarPinEnMapa();
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar ubicación'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Ingresar coordenadas manualmente',
            onPressed: _usarCoordenadasManuales,
          ),
        ],
      ),
      body: Stack(
        children: [
          MapaOffline(
            negocios: const [],
            negocioSeleccionadoId: null,
            centro: Coordenada(_lat, _lon),
            onNegocioTap: (_) {},
            onNegocioDetalle: (_) {},
            onMapTapped: _onMapTapped,
            onMapaCreado: _onMapaCreado,
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
          if (!_pinColocado)
            Positioned(
              left: 0,
              right: 0,
              bottom: 40,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app, size: 20, color: Colors.white70),
                      SizedBox(width: 8),
                      Text(
                        'Toca en el mapa para señalar la ubicación',
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _cargando
              ? const Center(child: CircularProgressIndicator())
              : FilledButton.icon(
                  onPressed: _confirmar,
                  icon: const Icon(Icons.check),
                  label: const Text('Confirmar ubicación'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
        ),
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
