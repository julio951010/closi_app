import 'package:flutter/material.dart';

class GaleriaFotos extends StatelessWidget {
  final List<String> urls;

  const GaleriaFotos({
    super.key,
    required this.urls,
  });

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.photo_library, size: 40, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
              const SizedBox(height: 8),
              Text(
                'Sin fotos disponibles',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length + 1,
        itemBuilder: (context, index) {
          if (index == urls.length) {
            // Botón de agregar foto
            return Container(
              width: 120,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
              ),
              child: InkWell(
                onTap: () {
                  // Agregar foto (luego)
                },
                borderRadius: BorderRadius.circular(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                    const SizedBox(height: 4),
                    Text(
                      'Agregar',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          }

          return Container(
            width: 120,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Placeholder de foto
                  Icon(
                    Icons.image,
                    size: 40,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      color: Colors.black54,
                      child: Text(
                        'Foto ${index + 1}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}