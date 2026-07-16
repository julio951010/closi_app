import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'mapa_screen.dart';
import 'favoritos_screen.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/menu_lateral.dart';
import '../services/sesion_service.dart';

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  int _indiceActual = 0;
  final _favoritosKey = GlobalKey<FavoritosScreenState>();

  late final List<Widget> _pantallas;

  @override
  void initState() {
    super.initState();
    _pantallas = [
      const HomeScreen(),
      const MapaScreen(),
      FavoritosScreen(key: _favoritosKey),
    ];
  }

  void _cambiarPestana(int indice) {
    setState(() {
      _indiceActual = indice;
    });
    if (indice == 2) _favoritosKey.currentState?.recargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      drawer: MenuLateral(usuario: SesionService.usuario),
      body: Builder(builder: (context) {
        switch (_indiceActual) {
          case 0: return _pantallas[0];
          case 1: return _pantallas[1];
          case 2: return _pantallas[2];
          default: return const SizedBox();
        }
      }),
      bottomNavigationBar: BottomNav(
        indiceActual: _indiceActual,
        onTap: _cambiarPestana,
      ),
    );
  }
}