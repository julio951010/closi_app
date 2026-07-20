import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/tema_service.dart';
import '../services/tema_mapa_service.dart';
import '../services/radio_busqueda_service.dart';
import '../services/connectivity_service.dart';
import '../services/negocio_service.dart';
import '../services/sesion_service.dart';
import '../services/sync_service.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  Timer? _syncTimer;
  StreamSubscription<bool>? _conexionSub;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();
    _inicializar();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _conexionSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _inicializar() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingCompletado = prefs.getBool('onboarding_completado') ?? false;

    await SesionService.inicializar();
    await TemaService.inicializar();
    await TemaMapaService.inicializar();
    await RadioBusquedaService.inicializar();

    // Verificar conexión a PostgreSQL
    final pgOk = await NegocioService.verificarConexion();
    if (!pgOk && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Sin conexión a la base de datos. La app usará datos guardados localmente.'),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ),
      );
    }

    _iniciarSincronizadoresPeriodicos();

    unawaited(SyncService.sincronizar().catchError((e) {
      debugPrint('SyncService: error inicial no capturado: $e');
    }));

    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      onboardingCompletado ? '/login' : '/onboarding',
    );
  }

  void _iniciarSincronizadoresPeriodicos() {
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(SyncService.sincronizar().catchError((e) {
        debugPrint('SyncService: error periódico no capturado: $e');
      }));
    });

    _conexionSub = ConnectivityService.cambios.listen((hayConexion) {
      if (hayConexion) {
        unawaited(SyncService.sincronizar().catchError((e) {
          debugPrint('SyncService: error por conectividad no capturado: $e');
        }));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1565C0),
              Color(0xFF0D47A1),
            ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/logo_name_down_white.png',
                  height: 140,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
