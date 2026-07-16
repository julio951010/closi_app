import 'package:flutter/material.dart';

class BarraBusqueda extends StatelessWidget {
  final Function(String)? onChanged;
  final VoidCallback? onFilterTap;

  const BarraBusqueda({
    super.key,
    this.onChanged,
    this.onFilterTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: 'Buscar negocios...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: onFilterTap != null
                  ? IconButton(
                icon: const Icon(Icons.tune),
                onPressed: onFilterTap,
              )
                  : null,
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ),
      ],
    );
  }
}