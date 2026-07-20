import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../database/negocio_dao.dart';
import '../models/negocio.dart';
import '../services/negocio_service.dart';
import '../services/radio_busqueda_service.dart';
import '../services/tema_mapa_service.dart';
import '../services/sesion_service.dart';
import '../widgets/mapa_offline.dart';
import 'detalle_negocio_screen.dart';

class MapaScreen extends StatefulWidget {
  final Negocio? negocioDestacado;

  const MapaScreen({super.key, this.negocioDestacado});

  @override
  State<MapaScreen> createState() => _MapaScreenState();
}

class _MapaScreenState extends State<MapaScreen> {
  final NegocioDao _negocioDao = NegocioDao();
  List<Negocio> _negocios = [];
  String? _seleccionadoId;
  bool _feedExpandido = false;
  Coordenada? _miUbicacion;
  double _lat = 23.113592;
  double _lon = -82.366592;
  StreamSubscription<Position>? _posicionSub;
  StreamSubscription<List<Negocio>>? _negocioSub;
  VoidCallback? _radioListener;
  VoidCallback? _cacheListener;
  static const _centroDefault = Coordenada(23.113592, -82.366592);
  static const double _alturaNav = 96.0;
  static const double _alturaPestana = 80.0;

  // Control del mapa
  MethodChannel? _mapaChannel;
  int _zoomActual = 13;

  int _zoomParaRadio(double km) =>
      (13 + (log(18 / km) / ln2)).round().clamp(8, 18);

  @override
  void initState() {
    super.initState();
    _negocioSub = NegocioService.stream.listen((negocios) {
      _cargarNegociosCerca(yCache: false);
    });
    _zoomActual = _zoomParaRadio(RadioBusquedaService.radioKm.value);
    _radioListener = () {
      if (!mounted) return;
      setState(() => _zoomActual = _zoomParaRadio(RadioBusquedaService.radioKm.value));
      _cargarNegociosCerca(yCache: false);
    };
    RadioBusquedaService.radioKm.addListener(_radioListener!);
    _cacheListener = () => _cargarNegociosCerca();
    NegocioService.cacheActualizada.addListener(_cacheListener!);
    if (widget.negocioDestacado != null) {
      final n = widget.negocioDestacado!;
      _lat = n.lat;
      _lon = n.lon;
      _negocios = [n];
      _seleccionadoId = n.id;
    }
    _iniciarUbicacion();
    if (widget.negocioDestacado == null) {
      _cargarNegociosCerca();
    }
  }

  @override
  void dispose() {
    _posicionSub?.cancel();
    _negocioSub?.cancel();
    if (_cacheListener != null) {
      NegocioService.cacheActualizada.removeListener(_cacheListener!);
    }
    if (_radioListener != null) {
      RadioBusquedaService.radioKm.removeListener(_radioListener!);
    }
    super.dispose();
  }

  Future<void> _iniciarUbicacion() async {
    bool permiso = await Geolocator.isLocationServiceEnabled();
    if (!permiso) {
      permiso = await Geolocator.openLocationSettings();
      return;
    }
    LocationPermission per = await Geolocator.checkPermission();
    if (per == LocationPermission.denied) {
      per = await Geolocator.requestPermission();
      if (per == LocationPermission.denied) return;
    }
    if (per == LocationPermission.deniedForever) return;

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    _actualizarUbicacion(pos);
    _cargarNegociosCerca();

    _posicionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((pos) {
      _actualizarUbicacion(pos);
      _cargarNegociosCerca(yCache: false);
    });
  }

  void _actualizarUbicacion(Position pos) {
    _lat = pos.latitude;
    _lon = pos.longitude;
    final coord = Coordenada(pos.latitude, pos.longitude);
    setState(() => _miUbicacion = coord);
    _mapaChannel?.invokeMethod('setMyLocation', {'lat': pos.latitude, 'lon': pos.longitude});
  }

  Future<void> _cargarNegociosCerca({bool yCache = true}) async {
    try {
      final negociosPropios = await _negocioDao.obtenerPropios(SesionService.usuarioId);
      final negociosCerca = await NegocioService.consultarCercaDe(
        lat: _lat,
        lon: _lon,
        radioKm: RadioBusquedaService.radioKm.value,
      );
      if (mounted) {
        final distancias = {for (final n in negociosCerca) if (n.distancia != null) n.id: n.distancia!};
        final ids = <String>{};
        _negocios = [...negociosPropios, ...negociosCerca]
            .where((n) => ids.add(n.id))
            .toList();
        for (final n in _negocios) {
          n.distancia ??= distancias[n.id];
        }
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error al cargar negocios para el mapa: $e');
    }
  }

  void _onMapaCreado(MethodChannel channel) {
    _mapaChannel = channel;
    if (widget.negocioDestacado != null) {
      final n = widget.negocioDestacado!;
      channel.invokeMethod('placePin', {'lat': n.lat, 'lon': n.lon});
    }
    if (_miUbicacion != null) {
      channel.invokeMethod('setMyLocation', {
        'lat': _miUbicacion!.latitude,
        'lon': _miUbicacion!.longitude,
      });
    }
  }

  void _onNegocioTap(Negocio n) {
    final yaSeleccionado = _seleccionadoId == n.id;
    setState(() {
      _seleccionadoId = yaSeleccionado ? null : n.id;
    });
    if (yaSeleccionado) {
      _mapaChannel?.invokeMethod('selectBusiness', {'id': null});
    } else {
      _mapaChannel?.invokeMethod('selectBusiness', {'id': n.id});
      _mapaChannel?.invokeMethod('setCenter', {'lat': n.lat, 'lon': n.lon});
    }
  }

  void _onNegocioDetalle(Negocio n) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => DetalleNegocioScreen(negocio: n)));
  void _deseleccionar() {
    setState(() => _seleccionadoId = null);
    _mapaChannel?.invokeMethod('selectBusiness', {'id': null});
  }
  void _toggleFeed() => setState(() => _feedExpandido = !_feedExpandido);

  void _acercar() {
    if (_zoomActual >= 20) return;
    final nuevoZoom = _zoomActual + 1;
    _mapaChannel?.invokeMethod('setZoom', {'zoom': nuevoZoom});
    setState(() => _zoomActual = nuevoZoom);
  }

  void _alejar() {
    if (_zoomActual <= 3) return;
    final nuevoZoom = _zoomActual - 1;
    _mapaChannel?.invokeMethod('setZoom', {'zoom': nuevoZoom});
    setState(() => _zoomActual = nuevoZoom);
  }

  void _centrarUbicacion() {
    _deseleccionar();
    final coord = _miUbicacion ?? _centroDefault;
    _mapaChannel?.invokeMethod('setCenter', {
      'lat': coord.latitude,
      'lon': coord.longitude,
    });
    if (_miUbicacion == null) _iniciarUbicacion();
  }

  void _abrirConfiguracion() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ConfiguracionMapa(),
    );
  }

  // Texto de escala según nivel de zoom
  String get _escalaTexto {
    const escalas = {
      3: '1000 km', 4: '500 km', 5: '200 km', 6: '100 km',
      7: '50 km',  8: '20 km',  9: '10 km',  10: '5 km',
      11: '2 km',  12: '1 km',  13: '500 m', 14: '200 m',
      15: '100 m', 16: '50 m',  17: '20 m',  18: '10 m',
      19: '5 m',   20: '2 m',
    };
    return escalas[_zoomActual] ?? '500 m';
  }

  @override
  Widget build(BuildContext context) {
    final alturaExpandida = MediaQuery.of(context).size.height * 0.45;
    final alturaPanelCerrado = _alturaPestana + _alturaNav;
    final topSafe = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: Stack(
        children: [
          // Mapa pantalla completa
          Positioned.fill(
            child: MapaOffline(
              negocios: _negocios,
              negocioSeleccionadoId: _seleccionadoId,
              centro: _miUbicacion ?? _centroDefault,
              onNegocioTap: _onNegocioTap,
              onNegocioDetalle: _onNegocioDetalle,
              onMapTapped: (_) => _deseleccionar(),
              onMapaCreado: _onMapaCreado,
              zoom: _zoomActual,
            ),
          ),

          // Botones flotantes derecha superior
          Positioned(
            top: topSafe + 12,
            right: 16,
            child: Column(
              children: [
                _BotonMapa(icono: Icons.tune_rounded, onTap: _abrirConfiguracion),
                const SizedBox(height: 10),
                _BotonMapa(icono: Icons.my_location_rounded, onTap: _centrarUbicacion),
                const SizedBox(height: 10),
                // Zoom in
                _BotonZoom(icono: Icons.add_rounded, onTap: _acercar, activo: _zoomActual < 20),
                const SizedBox(height: 2),
                // Zoom out
                _BotonZoom(icono: Icons.remove_rounded, onTap: _alejar, activo: _zoomActual > 3),
              ],
            ),
          ),

          // Escala del mapa — esquina inferior izquierda, encima del panel
          Positioned(
            left: 16,
            bottom: alturaPanelCerrado + 12,
            child: _EscalaMapa(texto: _escalaTexto),
          ),

          // Panel inferior
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
              height: _feedExpandido ? alturaExpandida : alturaPanelCerrado,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 15,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _toggleFeed,
                    onVerticalDragUpdate: (details) {
                      if (details.delta.dy < -4 && !_feedExpandido) {
                        setState(() => _feedExpandido = true);
                      } else if (details.delta.dy > 4 && _feedExpandido) {
                        setState(() => _feedExpandido = false);
                      }
                    },
                    child: SizedBox(
                      width: double.infinity,
                      height: _alturaPestana,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            width: 40, height: 4,
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          Row(children: [
                            Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1245A8).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.store, color: Color(0xFF1245A8), size: 18),
                            ),
                            const SizedBox(width: 8),
                            Text('${_negocios.length} negocios cercanos',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            const Spacer(),
                            Icon(
                              _feedExpandido ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                              color: const Color(0xFF1245A8), size: 24,
                            ),
                          ]),
                        ]),
                      ),
                    ),
                  ),
                  if (_feedExpandido)
                    Expanded(
                      child: _ListaNegocios(
                        negocios: _negocios,
                        seleccionadoId: _seleccionadoId,
                        onTap: _onNegocioTap,
                        onDetalle: _onNegocioDetalle,
                        bottomPadding: _alturaNav,
                      ),
                    ),
                  if (!_feedExpandido) const SizedBox(height: _alturaNav),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonMapa extends StatelessWidget {
  final IconData icono;
  final VoidCallback onTap;
  const _BotonMapa({required this.icono, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2), width: 1),
          ),
          child: Icon(icono, color: const Color(0xFF1245A8), size: 22),
        ),
      ),
    );
  }
}

class _BotonZoom extends StatelessWidget {
  final IconData icono;
  final VoidCallback onTap;
  final bool activo;
  const _BotonZoom({required this.icono, required this.onTap, required this.activo});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: activo ? onTap : null,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: activo ? 0.55 : 0.25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1),
        ),
        child: Icon(
          icono,
          color: activo
              ? const Color(0xFF1245A8).withValues(alpha: 0.85)
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          size: 22,
        ),
      ),
    );
  }
}

class _EscalaMapa extends StatelessWidget {
  final String texto;
  const _EscalaMapa({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 2,
            decoration: BoxDecoration(
              color: const Color(0xFF1245A8).withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            texto,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1245A8).withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfiguracionMapa extends StatefulWidget {
  @override
  State<_ConfiguracionMapa> createState() => _ConfiguracionMapaState();
}

class _ConfiguracionMapaState extends State<_ConfiguracionMapa> {
  @override
  void initState() {
    super.initState();
    TemaMapaService.actual.addListener(_onChanged);
  }

  @override
  void dispose() {
    TemaMapaService.actual.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final temaMapa = TemaMapaService.actual.value;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.map, size: 20),
              const SizedBox(width: 8),
              Text('Tema del mapa',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...TemaMapaService.temas.map((tema) => RadioListTile<String>(
            contentPadding: EdgeInsets.zero,
            title: Text(TemaMapaService.nombres[tema] ?? tema),
            subtitle: Text('$tema.xml', style: const TextStyle(fontSize: 12)),
            value: tema,
            groupValue: temaMapa,
            dense: true,
            visualDensity: VisualDensity.compact,
            onChanged: (v) { if (v != null) TemaMapaService.establecer(v); },
          )),
        ],
      ),
    );
  }
}

class _ListaNegocios extends StatelessWidget {
  final List<Negocio> negocios;
  final String? seleccionadoId;
  final Function(Negocio) onTap;
  final Function(Negocio) onDetalle;
  final double bottomPadding;
  const _ListaNegocios({required this.negocios, this.seleccionadoId, required this.onTap, required this.onDetalle, this.bottomPadding = 0});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 16 + bottomPadding),
      itemCount: negocios.length,
      itemBuilder: (_, i) {
        final n = negocios[i];
        final sel = seleccionadoId == n.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: SizedBox(
            height: 66,
            child: InkWell(
              onTap: () => onTap(n),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: sel ? const Color(0xFF1245A8).withValues(alpha: 0.08) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: sel ? const Color(0xFF1245A8) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2), width: sel ? 2 : 1),
                ),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1245A8).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(Negocio.getIcono(n.categoria), color: const Color(0xFF1245A8), size: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.nombre, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(Negocio.getNombreCategoria(n.categoria),
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 11)),
                    ],
                  )),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1245A8).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      n.distancia != null ? '${n.distancia!.toStringAsFixed(1)} km' : '--',
                      style: const TextStyle(color: Color(0xFF1245A8), fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => onDetalle(n),
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                      child: Icon(Icons.chevron_right, size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}