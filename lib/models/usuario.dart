class Usuario {
  final String id;
  final String nombre;
  final String? email;
  final String? telefono;
  final String? fotoUrl;
  final bool estaLogueado;
  final String rol;

  Usuario({
    this.id = '',
    required this.nombre,
    this.email,
    this.telefono,
    this.fotoUrl,
    this.estaLogueado = false,
    this.rol = 'cliente',
  });

  bool get esAdmin => rol == 'admin';
  bool get esInvitado => rol == 'invitado';

  static Usuario invitado = Usuario(nombre: 'Invitado');
}