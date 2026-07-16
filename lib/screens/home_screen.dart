import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../database/favorito_dao.dart';
import '../models/categoria.dart';
import '../models/favorito.dart';
import '../models/negocio.dart';
import '../services/negocio_service.dart';
import '../services/sesion_service.dart';
import '../services/sync_service.dart';
import '../widgets/cabecera_home.dart';
import '../widgets/filtro_categorias.dart';
import '../widgets/carrusel_destacados.dart';
import '../widgets/feed_negocios.dart';
import '../widgets/skeleton_home.dart';
import 'buscar_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FavoritoDao _favoritoDao = FavoritoDao();
  String? _categoriaSeleccionada;
  List<Negocio> _todosLosNegocios = [];
  List<Negocio> _negociosFiltrados = [];
  List<Categoria> _categorias = [];
  bool _cargando = true;
  bool _pgDesconectado = false;
  StreamSubscription<List<Negocio>>? _negocioSub;
  StreamSubscription<Position>? _posicionSub;
  VoidCallback? _pgListener;
  double _lat = 23.113592;
  double _lon = -82.366592;

  @override
  void initState() {
    super.initState();
    _pgDesconectado = !NegocioService.postgresDisponible.value;
    _pgListener = () {
      if (mounted) setState(() => _pgDesconectado = !NegocioService.postgresDisponible.value);
    };
    NegocioService.postgresDisponible.addListener(_pgListener!);
    _iniciar();
  }

  @override
  void dispose() {
    _negocioSub?.cancel();
    _posicionSub?.cancel();
    if (_pgListener != null) {
      NegocioService.postgresDisponible.removeListener(_pgListener!);
    }
    super.dispose();
  }

  Future<void> _iniciar() async {
    // Suscribirse a actualizaciones de NegocioService
    _negocioSub = NegocioService.stream.listen((negocios) {
      unawaited(_aplicarNegocios(negocios));
    });

    // Obtener ubicación inicial
    await _obtenerUbicacion();

    // Cargar categorías y primera consulta
    await _cargarDatos();
  }

  Future<void> _obtenerUbicacion() async {
    try {
      bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;
      LocationPermission per = await Geolocator.checkPermission();
      if (per == LocationPermission.denied) {
        per = await Geolocator.requestPermission();
        if (per == LocationPermission.denied) return;
      }
      if (per == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      _lat = pos.latitude;
      _lon = pos.longitude;

      // Escuchar cambios de ubicación (cada 100m)
      _posicionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 100,
        ),
      ).listen((pos) {
        _lat = pos.latitude;
        _lon = pos.longitude;
        _consultarNegocios();
      });
    } catch (_) {}
  }

  Future<void> _cargarDatos() async {
    try {
      final catsData = await DatabaseHelper.obtenerCategorias();
      final cats = catsData.map((c) => Categoria.fromMap(c)).toList();

      if (mounted) setState(() => _categorias = cats);

      // Si NegocioService ya tiene datos, usarlos
      if (NegocioService.ultimosNegocios.isNotEmpty) {
        _aplicarNegocios(NegocioService.ultimosNegocios);
      } else {
        await _consultarNegocios();
      }
    } catch (e) {
      debugPrint('HomeScreen: error al cargar datos — $e');
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _consultarNegocios() async {
    final negocios = await NegocioService.consultarCercaDe(
      lat: _lat,
      lon: _lon,
    );
    _aplicarNegocios(negocios);
  }

  Future<void> _aplicarNegocios(List<Negocio> negocios) async {
    final idsFavoritos = await _favoritoDao.obtenerIdsFavoritos(SesionService.usuarioId);
    final marcados = negocios
        .map((n) => n.copyWith(esFavorito: idsFavoritos.contains(n.id)))
        .toList();
    if (mounted) {
      setState(() {
        _todosLosNegocios = marcados;
        _negociosFiltrados = _categoriaSeleccionada == null
            ? marcados
            : marcados.where((n) => n.categoria == _categoriaSeleccionada).toList();
        _cargando = false;
      });
    }
  }

  void _filtrarPorCategoria(String? categoriaId) {
    setState(() {
      _categoriaSeleccionada = categoriaId;
      if (categoriaId == null) {
        _negociosFiltrados = List<Negocio>.from(_todosLosNegocios);
      } else {
        final categoria = _categorias.firstWhere(
              (c) => c.id == categoriaId,
          orElse: () => Categoria(id: '', nombre: '', icono: '', color: ''),
        );
        _negociosFiltrados = _todosLosNegocios
            .where((n) => n.categoria == categoria.nombre.toLowerCase())
            .toList();
      }
    });
  }

  Future<void> _toggleFavorito(Negocio negocio) async {
    final nuevoEstado = !negocio.esFavorito;

    // Actualización optimista en UI
    setState(() {
      void actualizar(List<Negocio> lista) {
        final index = lista.indexWhere((n) => n.id == negocio.id);
        if (index != -1) lista[index] = negocio.copyWith(esFavorito: nuevoEstado);
      }
      actualizar(_todosLosNegocios);
      actualizar(_negociosFiltrados);
    });

    try {
      if (nuevoEstado) {
        await _favoritoDao.agregar(Favorito(
          id: const Uuid().v4(),
          usuarioId: SesionService.usuarioId,
          negocioId: negocio.id,
          fecha: DateTime.now(),
        ));
      } else {
        await _favoritoDao.quitar(SesionService.usuarioId, negocio.id);
      }
      unawaited(SyncService.sincronizar());
    } catch (e) {
      debugPrint('Error al guardar favorito: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: _cargando
            ? const SkeletonHome()
            : Column(
          children: [
            if (_pgDesconectado)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.orange.shade800,
                child: Row(
                  children: [
                    Icon(Icons.cloud_off, size: 18, color: Colors.white.withValues(alpha: 0.9)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Modo sin conexión — mostrando datos guardados',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            CabeceraHome(
              nombreUsuario: SesionService.usuario.nombre.split(' ')[0],
              onMenuTap: () => Scaffold.of(context).openDrawer(),
              onSearchTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => BuscarScreen(lat: _lat, lon: _lon)));
              },
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    FiltroCategorias(
                      categorias: _categorias,
                      seleccionada: _categoriaSeleccionada,
                      onSelected: _filtrarPorCategoria,
                    ),
                    const SizedBox(height: 20),
                    if (_categoriaSeleccionada == null) ...[
                      CarruselDestacados(
                        destacados: _todosLosNegocios.where((n) => n.esDestacado).toList(),
                        onFavoritoToggle: _toggleFavorito,
                      ),
                      const SizedBox(height: 20),
                    ],
                    FeedNegocios(
                      negocios: _negociosFiltrados,
                      onFavoritoToggle: _toggleFavorito,
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}