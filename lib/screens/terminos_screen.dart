import 'package:flutter/material.dart';

class TerminosScreen extends StatelessWidget {
  const TerminosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Términos de uso')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Términos de uso', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
            const SizedBox(height: 16),
            Text(
              'Última actualización: 1 de julio de 2026',
              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 13),
            ),
            const SizedBox(height: 24),
            _seccion(theme, '1. Aceptación de los términos',
                'Al usar Closi, aceptas estos términos de uso. Si no estás de acuerdo, no utilices la aplicación.'),
            _seccion(theme, '2. Descripción del servicio',
                'Closi es una plataforma que te permite descubrir negocios y servicios cercanos a tu ubicación en Cuba. Los datos mostrados son proporcionados por los propios negocios y pueden no estar actualizados.'),
            _seccion(theme, '3. Responsabilidades del usuario',
                'Eres responsable de la veracidad de la información que proporcionas. No debes usar la aplicación para fines ilícitos o no autorizados.'),
            _seccion(theme, '4. Opiniones y contenido',
                'Las opiniones que publicas deben ser respetuosas y veraces. Nos reservamos el derecho de eliminar contenido inapropiado.'),
            _seccion(theme, '5. Limitación de responsabilidad',
                'Closi no se hace responsable por la exactitud de la información de los negocios ni por cualquier daño derivado del uso de la aplicación.'),
            _seccion(theme, '6. Modificaciones',
                'Podemos modificar estos términos en cualquier momento. El uso continuado de la aplicación después de los cambios constituye la aceptación de los nuevos términos.'),
          ],
        ),
      ),
    );
  }

  Widget _seccion(ThemeData theme, String titulo, String contenido) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titulo, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
        const SizedBox(height: 8),
        Text(contenido, style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.7), height: 1.5)),
      ]),
    );
  }
}
