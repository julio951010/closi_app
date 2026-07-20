import 'dart:io';
import 'package:flutter/material.dart';
import '../models/negocio.dart';
import '../screens/detalle_negocio_screen.dart';

class TarjetaNegocio extends StatelessWidget {
  final Negocio negocio;
  final VoidCallback? onTap;
  final VoidCallback? onFavoritoToggle;

  const TarjetaNegocio({
    super.key,
    required this.negocio,
    this.onTap,
    this.onFavoritoToggle,
  });

  @override
  Widget build(BuildContext context) {
    final distColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Theme.of(context).primaryColor;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap ??
                () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DetalleNegocioScreen(negocio: negocio),
                ),
              );
            },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // IMAGEN DEL NEGOCIO O PLACEHOLDER
              _buildImagenNegocio(context),
              const SizedBox(width: 12),
              // Información
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      negocio.nombre,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Negocio.getNombreCategoria(negocio.categoria),
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: distColor),
                        const SizedBox(width: 2),
                        Text(
                          negocio.distancia != null ? '${negocio.distancia!.toStringAsFixed(1)} km' : '-- km',
                          style: TextStyle(color: distColor, fontSize: 12),
                        ),
                        if (negocio.calificacion != null) ...[
                          const SizedBox(width: 12),
                          Icon(Icons.star, size: 14, color: Colors.amber[700]),
                          const SizedBox(width: 2),
                          Text(
                            negocio.calificacion!.toStringAsFixed(1),
                            style: TextStyle(color: Colors.amber[700], fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Botón favorito
              GestureDetector(
                onTap: onFavoritoToggle,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    negocio.esFavorito ? Icons.favorite : Icons.favorite_border,
                    color: negocio.esFavorito ? Colors.red : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Construye la imagen del negocio o un placeholder por categoría
  Widget _buildImagenNegocio(BuildContext context) {
    final color = _colorCategoria(negocio.categoria);

    // Si tiene fotos, mostrar la primera
    if (negocio.fotos.isNotEmpty) {
      final fotoUrl = negocio.fotos.first;
      final esLocal = !fotoUrl.startsWith('http') && File(fotoUrl).existsSync();
      return Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: color.withValues(alpha: 0.15),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: esLocal
              ? Image.file(File(fotoUrl), fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _imagenPlaceholder(color, 30))
              : Image.network(fotoUrl, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _imagenPlaceholder(color, 30)),
        ),
      );
    }

    // Placeholder por categoría
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: _imagenPlaceholder(color, 30),
    );
  }

  /// Placeholder con icono de la categoría
  Widget _imagenPlaceholder(Color color, double size) {
    return Center(
      child: Icon(
        Negocio.getIcono(negocio.categoria),
        color: color,
        size: size,
      ),
    );
  }

  Color _colorCategoria(String cat) {
    switch (cat) {
      case 'restaurante': return const Color(0xFFE65100);
      case 'cafeteria': return const Color(0xFF6D4C41);
      case 'farmacia': return const Color(0xFF00C853);
      case 'hospital': return const Color(0xFFD50000);
      case 'hotel': return const Color(0xFF2962FF);
      case 'banco': return const Color(0xFF6200EA);
      case 'wifi': return const Color(0xFF00BCD4);
      case 'tienda': return const Color(0xFFFF6F00);
      case 'taller': return const Color(0xFF607D8B);
      case 'transporte': return const Color(0xFFFF5722);
      default: return const Color(0xFF1565C0);
    }
  }
}