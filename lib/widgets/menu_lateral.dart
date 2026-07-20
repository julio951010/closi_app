import 'package:flutter/material.dart';
import '../models/usuario.dart';
import '../services/sesion_service.dart';

class MenuLateral extends StatelessWidget {
  final Usuario usuario;

  const MenuLateral({super.key, required this.usuario});

  @override
  Widget build(BuildContext context) {
    final esOscuro = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: esOscuro ? 0.2 : 0.1),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Image.asset(
                      esOscuro ? 'assets/images/logo_name_side_white.png' : 'assets/images/logo_name_side_blue.png',
                      height: 40,
                      fit: BoxFit.contain,
                    ),
                  ),
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: theme.primaryColor,
                    child: Text(
                      (usuario.nombre.isNotEmpty ? usuario.nombre[0] : '?').toUpperCase(),
                      style: const TextStyle(fontSize: 32, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(usuario.nombre, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                  if (usuario.email != null) ...[
                    const SizedBox(height: 4),
                    Text(usuario.email!, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 14)),
                  ],
                  if (usuario.telefono != null) ...[
                    const SizedBox(height: 2),
                    Text(usuario.telefono!, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 14)),
                  ],
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  if (!usuario.esInvitado) ListTile(
                    leading: const Icon(Icons.person),
                    title: const Text('Perfil'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/perfil');
                    },
                  ),
                  if (!usuario.esInvitado) ListTile(
                    leading: const Icon(Icons.store),
                    title: const Text('Negocios'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/business');
                    },
                  ),
                  if (usuario.esAdmin) ListTile(
                    leading: const Icon(Icons.admin_panel_settings),
                    title: const Text('Panel de administración'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/admin');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text('Configuración'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/configuracion');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.info),
                    title: const Text('Acerca de Closi'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/acerca');
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      usuario.esInvitado ? Icons.login : Icons.logout,
                      color: usuario.esInvitado ? null : Colors.red,
                    ),
                    title: Text(
                      usuario.esInvitado ? 'Iniciar sesión' : 'Cerrar sesión',
                      style: TextStyle(color: usuario.esInvitado ? null : Colors.red),
                    ),
                    onTap: () async {
                      if (!usuario.esInvitado) {
                        await SesionService.cerrarSesion();
                      }
                      if (context.mounted) {
                        Navigator.pop(context);
                        Navigator.pushReplacementNamed(context, '/login');
                      }
                    },
                  ),
                ],
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                '© ${DateTime.now().year} Closi App. Todos los derechos reservados.',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}