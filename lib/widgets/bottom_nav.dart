import 'package:flutter/material.dart';

class BottomNav extends StatelessWidget {
  final int indiceActual;
  final Function(int) onTap;

  const BottomNav({
    super.key,
    required this.indiceActual,
    required this.onTap,
  });

  static const _items = [
    _NavData(icono: Icons.explore_rounded, label: 'Explorar'),
    _NavData(icono: Icons.map_rounded, label: 'Mapa'),
    _NavData(icono: Icons.favorite_rounded, label: 'Favoritos'),
  ];

  @override
  Widget build(BuildContext context) {
    // Detecta el área segura del sistema en la parte inferior (barra de gestos)
    final double safeAreaBottom = MediaQuery.of(context).padding.bottom;

    return Container(
      color: Colors.transparent,
      // Si el dispositivo tiene barra de gestos, suma su altura + un respiro de 12px. Si no, mantiene los 16px base.
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        safeAreaBottom > 0 ? safeAreaBottom + 12 : 16,
      ),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: const Color(0xFF0F1729),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1245A8).withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: List.generate(_items.length, (i) {
            final activo = i == indiceActual;
            return Expanded(
              child: GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  margin: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: activo ? const Color(0xFF1245A8) : Colors.transparent,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _items[i].icono,
                        size: 22,
                        color: activo
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _items[i].label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: activo ? FontWeight.w600 : FontWeight.w400,
                          color: activo
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavData {
  final IconData icono;
  final String label;
  const _NavData({required this.icono, required this.label});
}