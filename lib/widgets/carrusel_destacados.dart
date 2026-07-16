import 'package:flutter/material.dart';
import '../models/negocio.dart';
import '../screens/detalle_negocio_screen.dart';

class CarruselDestacados extends StatelessWidget {
  final List<Negocio> destacados;
  final Function(Negocio)? onFavoritoToggle;

  const CarruselDestacados({
    super.key,
    required this.destacados,
    this.onFavoritoToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (destacados.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Destacados',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: destacados.length,
            itemBuilder: (context, index) {
              return SizedBox(
                width: 280,
                child: _TarjetaDestacado(
                  negocio: destacados[index],
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DetalleNegocioScreen(negocio: destacados[index]),
                      ),
                    );
                  },
                  onFavoritoToggle: () => onFavoritoToggle?.call(destacados[index]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TarjetaDestacado extends StatelessWidget {
  final Negocio negocio;
  final VoidCallback onTap;
  final VoidCallback onFavoritoToggle;

  const _TarjetaDestacado({
    required this.negocio,
    required this.onTap,
    required this.onFavoritoToggle,
  });

  @override
  Widget build(BuildContext context) {
    final distColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Theme.of(context).primaryColor;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // IMAGEN DE PORTADA
            Stack(
              children: [
                Container(
                  height: 110,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _colorCategoria(negocio.categoria).withValues(alpha: 0.12),
                  ),
                  child: _imagenPortada(context),
                ),
              ],
            ),

            // INFORMACIÓN
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      negocio.nombre,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Negocio.getNombreCategoria(negocio.categoria),
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 12),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: distColor),
                        const SizedBox(width: 2),
                        Text(
                          negocio.distancia != null ? '${negocio.distancia!.toStringAsFixed(1)} km' : '-- km',
                          style: TextStyle(color: distColor, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star, size: 12, color: Colors.amber[700]),
                              const SizedBox(width: 2),
                              Text(
                                negocio.calificacion?.toStringAsFixed(1) ?? '--',
                                style: TextStyle(color: Colors.amber[700], fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _estaAbierto() ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _estaAbierto() ? 'Abierto' : 'Cerrado',
                            style: TextStyle(
                              color: _estaAbierto() ? Colors.green[700] : Colors.red[700],
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagenPortada(BuildContext context) {
    final color = _colorCategoria(negocio.categoria);

    // Si tiene fotos, mostrar la primera
    if (negocio.fotos.isNotEmpty) {
      return Container(
        height: 110,
        width: double.infinity,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
        ),
        child: Center(
          child: Icon(
            Negocio.getIcono(negocio.categoria),
            size: 45,
            color: color.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    // Placeholder por categoría
    return Container(
      height: 110,
      width: double.infinity,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Negocio.getIcono(negocio.categoria),
              size: 40,
              color: color.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 4),
            Text(
              'Sin imagen',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 11),
            ),
          ],
        ),
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

  bool _estaAbierto() {
    if (negocio.horario == null) return false;
    final horario = negocio.horario!.toLowerCase();
    if (horario.contains('24 horas')) return true;
    final hora = DateTime.now().hour;
    return hora >= 8 && hora < 22;
  }
}