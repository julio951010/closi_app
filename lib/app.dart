import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'services/tema_service.dart';
import 'screens/loading_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/pantalla_principal.dart';
import 'screens/perfil_screen.dart';
import 'screens/configuracion_screen.dart';
import 'screens/agregar_negocio_screen.dart';
import 'screens/business_screen.dart';
import 'screens/acerca_screen.dart';
import 'screens/admin_screen.dart';

class _SinTransicion extends PageTransitionsBuilder {
  const _SinTransicion();
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) => child;
}

class ClosiApp extends StatefulWidget {
  const ClosiApp({super.key});

  @override
  State<ClosiApp> createState() => _ClosiAppState();
}

class _ClosiAppState extends State<ClosiApp> {
  @override
  void initState() {
    super.initState();
    TemaService.modo.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    TemaService.modo.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Closi',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme.copyWith(
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: _SinTransicion(),
            TargetPlatform.iOS: _SinTransicion(),
          },
        ),
      ),
      darkTheme: AppTheme.darkTheme.copyWith(
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: _SinTransicion(),
            TargetPlatform.iOS: _SinTransicion(),
          },
        ),
      ),
      themeMode: TemaService.modo.value,
      initialRoute: '/loading',
      routes: {
        '/loading': (context) => const LoadingScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginScreen(),
        '/principal': (context) => const PantallaPrincipal(),
        '/perfil': (context) => const PerfilScreen(),
        '/configuracion': (context) => const ConfiguracionScreen(),
        '/business': (context) => const BusinessScreen(),
        '/agregar-negocio': (context) => const AgregarNegocioScreen(),
        '/acerca': (context) => const AcercaScreen(),
        '/admin': (context) => const AdminScreen(),
      },
    );
  }
}
