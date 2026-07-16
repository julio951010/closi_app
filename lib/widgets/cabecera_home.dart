import 'package:flutter/material.dart';

class CabeceraHome extends StatelessWidget {
  final String nombreUsuario;
  final VoidCallback onMenuTap;
  final VoidCallback onSearchTap;

  const CabeceraHome({
    super.key,
    required this.nombreUsuario,
    required this.onMenuTap,
    required this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final esOscuro = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.menu),
                onPressed: onMenuTap,
              ),
              const Spacer(),
              Image.asset(
                esOscuro
                    ? 'assets/images/logo_name_side_white.png'
                    : 'assets/images/logo_name_side_blue.png',
                height: 36,
                fit: BoxFit.contain,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: onSearchTap,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '¡Hola, $nombreUsuario!',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            'Descubre negocios y servicios cerca de ti',
            style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 14),
          ),
        ],
      ),
    );
  }
}