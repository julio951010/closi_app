import 'package:flutter/material.dart';
import '../services/sesion_service.dart';

class PermisosService {
  static bool get esInvitado => SesionService.usuario.esInvitado;
  static bool get esCliente => SesionService.usuario.rol == 'cliente';
  static bool get esAdmin => SesionService.usuario.esAdmin;

  static bool get puedeCalificar => !esInvitado;
  static bool get puedeOpinar => !esInvitado;
  static bool get puedeFavorito => !esInvitado;
  static bool get puedeGestionarNegocioPropio => !esInvitado;
  static bool get puedeVerPerfil => !esInvitado;
  static bool get puedeVerFavoritos => !esInvitado;
  static bool get puedeVerNegocios => !esInvitado;

  static bool get puedeModerarOpiniones => esAdmin;
  static bool get puedeGestionarUsuarios => esAdmin;
  static bool get puedeGestionarCategorias => esAdmin;
  static bool get puedeGestionarTodosNegocios => esAdmin;
  static bool get puedeGestionarProductosServicios => esAdmin;
  static bool get puedeGestionarCalificaciones => esAdmin;

  static void mostrarDialogoAutenticacion(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Acceso restringido'),
        content: const Text('Debe autenticarse para entrar a esta página'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () {
            Navigator.pop(ctx);
            Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
          }, child: const Text('Iniciar sesión')),
        ],
      ),
    );
  }

  static void mostrarSnackbarAutenticacion(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Debe iniciar sesión para realizar esta acción'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 3),
      ),
    );
  }
}
