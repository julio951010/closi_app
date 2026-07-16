import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'privacidad_screen.dart';
import 'terminos_screen.dart';

class AcercaScreen extends StatelessWidget {
  const AcercaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final esOscuro = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Acerca de Closi')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        children: [
          Center(
            child: Column(children: [
              Image.asset(
                esOscuro ? 'assets/images/logo_name_down_white.png' : 'assets/images/logo_name_down_blue.png',
                height: 100, fit: BoxFit.contain,
              ),
              const SizedBox(height: 12),
              Text('Versión 1.0.0', style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
              const SizedBox(height: 12),
              Text(
                'Closi te ayuda a encontrar negocios y servicios cercanos a tu ubicación en Cuba.',
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.5), height: 1.5),
              ),
            ]),
          ),
          const SizedBox(height: 32),
          const Divider(),
          _buildSeccion(context, 'Desarrollado por', 'JCHD', Icons.code, null),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Contacto', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface.withValues(alpha: 0.8))),
          ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _socialBoton(context, FontAwesomeIcons.whatsapp, const Color(0xFF25D366), 'WhatsApp', () =>
                url_launcher.launchUrl(Uri.parse('https://wa.me/5354222998'), mode: url_launcher.LaunchMode.externalApplication)),
            const SizedBox(width: 24),
            _socialBoton(context, FontAwesomeIcons.telegram, const Color(0xFF0088CC), 'Telegram', () =>
                url_launcher.launchUrl(Uri.parse('https://t.me/juliocesar_hd'), mode: url_launcher.LaunchMode.externalApplication)),
          ]),
          const Divider(),
          _buildSeccion(context, 'Políticas de privacidad', null, Icons.privacy_tip, () =>
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacidadScreen()))),
          _buildSeccion(context, 'Términos de uso', null, Icons.article, () =>
              Navigator.push(context, MaterialPageRoute(builder: (_) => const TerminosScreen()))),
          const Divider(),
          _buildSeccion(context, 'Licencias', null, Icons.description, () =>
              showLicensePage(context: context, applicationName: 'Closi')),
        ],
      ),
    );
  }

  Widget _buildSeccion(BuildContext context, String? titulo, String? subtitulo, IconData icono, VoidCallback? onTap) {
    return ListTile(
      leading: Icon(icono),
      title: Text(titulo ?? subtitulo ?? ''),
      subtitle: subtitulo != null && titulo != null ? Text(subtitulo) : null,
      trailing: onTap != null ? const Icon(Icons.chevron_right, size: 20) : null,
      onTap: onTap,
    );
  }

  Widget _socialBoton(BuildContext context, dynamic icono, Color color, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 52, height: 52, alignment: Alignment.center,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: FaIcon(icono, size: 26, color: color)),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
      ]),
    );
  }
}