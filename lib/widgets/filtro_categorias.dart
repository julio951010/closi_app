import 'package:flutter/material.dart';
import '../models/categoria.dart';

class FiltroCategorias extends StatelessWidget {
  final List<Categoria> categorias;
  final String? seleccionada;
  final Function(String?) onSelected;

  const FiltroCategorias({
    super.key,
    required this.categorias,
    this.seleccionada,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (categorias.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Categorías',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 80,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _CategoriaChip(
                icono: Icons.all_inclusive,
                nombre: 'Todas',
                color: '#1565C0',
                seleccionada: seleccionada == null,
                onTap: () => onSelected(null),
              ),
              ...categorias.map((cat) => _CategoriaChip(
                icono: _obtenerIcono(cat.icono ?? 'store'),
                nombre: cat.nombre,
                color: cat.color ?? '#1565C0',
                seleccionada: seleccionada == cat.id,
                onTap: () => onSelected(cat.id),
              )),
            ],
          ),
        ),
      ],
    );
  }

  IconData _obtenerIcono(String nombreIcono) {
    switch (nombreIcono) {
      case 'restaurant': return Icons.restaurant;
      case 'coffee': return Icons.coffee;
      case 'local_pharmacy': return Icons.local_pharmacy;
      case 'shopping_bag': return Icons.shopping_bag;
      case 'build': return Icons.build;
      case 'hotel': return Icons.hotel;
      case 'local_hospital': return Icons.local_hospital;
      case 'account_balance': return Icons.account_balance;
      case 'wifi': return Icons.wifi;
      case 'directions_bus': return Icons.directions_bus;
      default: return Icons.store;
    }
  }

}

class _CategoriaChip extends StatelessWidget {
  final IconData icono;
  final String nombre;
  final String color;
  final bool seleccionada;
  final VoidCallback onTap;

  const _CategoriaChip({
    required this.icono,
    required this.nombre,
    required this.color,
    required this.seleccionada,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorReal = Color(int.parse(color.replaceFirst('#', '0xFF')));
    final theme = Theme.of(context);
    final esOscuro = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: seleccionada ? colorReal : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: esOscuro ? 0.2 : 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icono,
              color: seleccionada ? Colors.white : colorReal,
              size: 30,
            ),
            const SizedBox(height: 6),
            Text(
              nombre,
              style: TextStyle(
                fontSize: 11,
                color: seleccionada ? Colors.white : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}