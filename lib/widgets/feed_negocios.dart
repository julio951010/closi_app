import 'package:flutter/material.dart';
import '../models/negocio.dart';
import 'tarjeta_negocio.dart';

class FeedNegocios extends StatelessWidget {
  final List<Negocio> negocios;
  final Function(Negocio)? onFavoritoToggle;

  const FeedNegocios({
    super.key,
    required this.negocios,
    this.onFavoritoToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título + contador
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Text(
                'Cercanos a ti',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              // Contador simple
              Text(
                '${negocios.length} resultado${negocios.length != 1 ? 's' : ''}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Lista de negocios
        ...negocios.map((n) => TarjetaNegocio(
          negocio: n,
          onFavoritoToggle: () => onFavoritoToggle?.call(n),
        )),
        const SizedBox(height: 20),
      ],
    );
  }
}