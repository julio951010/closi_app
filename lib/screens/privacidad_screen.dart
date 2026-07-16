import 'package:flutter/material.dart';

class PrivacidadScreen extends StatelessWidget {
  const PrivacidadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Políticas de privacidad')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Políticas de privacidad', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
            const SizedBox(height: 16),
            Text(
              'Última actualización: 1 de julio de 2026',
              style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 13),
            ),
            const SizedBox(height: 24),
            _seccion(theme, '1. Información que recopilamos',
                'Closi recopila la información que nos proporcionas al registrarte, incluyendo tu nombre, correo electrónico y número de teléfono. También recopilamos datos de ubicación para mostrarte negocios cercanos.'),
            _seccion(theme, '2. Uso de la información',
                'Utilizamos tu información para:\n- Mostrarte negocios y servicios cercanos a tu ubicación.\n- Permitirte guardar favoritos y dejar opiniones.\n- Mejorar nuestros servicios y la experiencia del usuario.'),
            _seccion(theme, '3. Compartir información',
                'No compartimos tu información personal con terceros sin tu consentimiento, excepto cuando sea requerido por ley.'),
            _seccion(theme, '4. Seguridad',
                'Implementamos medidas de seguridad para proteger tu información contra acceso no autorizado, alteración o divulgación.'),
            _seccion(theme, '5. Tus derechos',
                'Puedes solicitar la eliminación de tu cuenta y datos personales en cualquier momento contactándonos a través de los canales disponibles en la aplicación.'),
            _seccion(theme, '6. Cambios',
                'Nos reservamos el derecho de actualizar estas políticas. Notificaremos cualquier cambio significativo a través de la aplicación.'),
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
