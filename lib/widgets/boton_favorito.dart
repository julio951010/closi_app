import 'package:flutter/material.dart';

class BotonFavorito extends StatelessWidget {
  final bool esFavorito;
  final VoidCallback? onPressed;
  final double size;

  const BotonFavorito({
    super.key,
    required this.esFavorito,
    this.onPressed,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        esFavorito ? Icons.favorite : Icons.favorite_border,
        color: esFavorito ? Colors.red : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
        size: size,
      ),
      onPressed: onPressed,
    );
  }
}