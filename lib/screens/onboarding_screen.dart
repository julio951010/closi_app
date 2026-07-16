import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _pages = [
    _PageData(
      emoji: '📍',
      title: 'Descubre lo que\nestá cerca',
      description: 'Restaurantes, farmacias, talleres y más — todo a tu alrededor, sin conexión a internet.',
      gradientColors: [Color(0xFF0A2E6E), Color(0xFF1245A8)],
    ),
    _PageData(
      emoji: '🗺️',
      title: 'Mapa offline\nde Cuba',
      description: 'Navega sin internet. El mapa completo de Cuba siempre disponible en tu bolsillo.',
      gradientColors: [Color(0xFF0D3B6E), Color(0xFF1A6BAE)],
    ),
    _PageData(
      emoji: '❤️',
      title: 'Guarda tus\nlugares',
      description: 'Marca favoritos y accede a ellos al instante. Tu guía personal de la ciudad.',
      gradientColors: [Color(0xFF6B1A1A), Color(0xFFBF3A2B)],
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _completarOnboarding(String ruta) {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('onboarding_completado', true);
    }).catchError((_) {});
    Navigator.pushReplacementNamed(context, ruta);
  }

  @override
  Widget build(BuildContext context) {
    final esUltima = _currentPage == _pages.length - 1;

    return Scaffold(
      body: Stack(
        children: [
          // Fondo gradiente (no animado para evitar stutter en emulador)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _pages[_currentPage].gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Patrón de puntos
          RepaintBoundary(
            child: Opacity(
              opacity: 0.06,
              child: CustomPaint(
                size: MediaQuery.of(context).size,
                painter: _DotPatternPainter(),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Botón saltar (solo si no es la última)
                SizedBox(
                  height: 52,
                  child: !esUltima
                      ? Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: TextButton(
                        onPressed: () => _completarOnboarding('/principal'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white.withValues(alpha: 0.6),
                        ),
                        child: const Text('Saltar', style: TextStyle(fontSize: 14)),
                      ),
                    ),
                  )
                      : const SizedBox.shrink(),
                ),

                // Páginas
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemCount: _pages.length,
                    itemBuilder: (_, i) => _OnboardingPage(data: _pages[i]),
                  ),
                ),

                // Indicadores
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pages.length, (i) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: _currentPage == i ? 28 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _currentPage == i
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 40),

                // Botones
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: esUltima
                      ? SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: () => _completarOnboarding('/login'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF1245A8),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text('Comenzar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                          ),
                        )
                      : SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeOutCubic,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withValues(alpha: 0.2),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text('Siguiente', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                        ),

                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PageData {
  final String emoji;
  final String title;
  final String description;
  final List<Color> gradientColors;

  const _PageData({
    required this.emoji,
    required this.title,
    required this.description,
    required this.gradientColors,
  });
}

class _OnboardingPage extends StatelessWidget {
  final _PageData data;
  const _OnboardingPage({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Center(
              child: Text(data.emoji, style: const TextStyle(fontSize: 40)),
            ),
          ),
          const SizedBox(height: 40),
          Text(
            data.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            data.description,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 16,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    const spacing = 28.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}