import 'package:flutter/material.dart';
import '../database/favorito_dao.dart';
import '../database/negocio_dao.dart';
import '../models/negocio.dart';
import '../services/permisos_service.dart';
import '../services/sesion_service.dart';
import '../widgets/tarjeta_negocio.dart';

class FavoritosScreen extends StatefulWidget {
  const FavoritosScreen({super.key});

  @override
  State<FavoritosScreen> createState() => FavoritosScreenState();
}

class FavoritosScreenState extends State<FavoritosScreen> {
  final FavoritoDao _favoritoDao = FavoritoDao();
  final NegocioDao _negocioDao = NegocioDao();
  List<Negocio> _favoritos = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarFavoritos();
  }

  Future<void> _cargarFavoritos() async {
    setState(() => _cargando = true);
    try {
      final ids = await _favoritoDao.obtenerIdsFavoritos(SesionService.usuarioId);
      final idsList = ids.toList();
      final negociosCache = await _negocioDao.obtenerCachePorIds(idsList);
      final negociosPropios = await _negocioDao.obtenerPropiosPorIds(idsList);
      final negocios = [...negociosPropios, ...negociosCache];
      final marcados = negocios.map((n) => n.copyWith(esFavorito: true)).toList();
      if (mounted) {
        setState(() {
          _favoritos = marcados;
          _cargando = false;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar favoritos: $e');
      if (mounted) setState(() => _cargando = false);
    }
  }

  void recargar() => _cargarFavoritos();

  Future<void> _toggleFavorito(Negocio negocio) async {
    setState(() {
      _favoritos.removeWhere((n) => n.id == negocio.id);
    });
    try {
      await _favoritoDao.quitar(SesionService.usuarioId, negocio.id);
    } catch (e) {
      debugPrint('Error al quitar favorito: $e');
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Eliminado de favoritos'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (PermisosService.esInvitado) {
      return Scaffold(
        appBar: AppBar(title: const Text('Favoritos'), automaticallyImplyLeading: false),
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.lock_outline, size: 64, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            const Text('Debe autenticarse para entrar a esta página', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false), child: const Text('Iniciar sesión')),
          ]),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favoritos'),
        automaticallyImplyLeading: false,
        actions: [
          if (_favoritos.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.sort),
              onPressed: () {
                setState(() {
                  _favoritos.sort((a, b) => (a.distancia ?? 999).compareTo(b.distancia ?? 999));
                });
              },
            ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1565C0)))
          : _favoritos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.favorite_border, size: 80, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      Text('No tienes favoritos', style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
                      const SizedBox(height: 8),
                      Text('Guarda negocios tocando el corazón', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(8, 8, 8, MediaQuery.of(context).padding.bottom + 80),
                  itemCount: _favoritos.length,
                  itemBuilder: (context, index) {
                    return TarjetaNegocio(
                      negocio: _favoritos[index],
                      onFavoritoToggle: () => _toggleFavorito(_favoritos[index]),
                    );
                  },
                ),
      //bottomNavigationBar: const BottomNav(indiceActual: 2),
    );
  }
}
