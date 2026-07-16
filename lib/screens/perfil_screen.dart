import 'dart:async';
import 'dart:io';
import 'package:bcrypt/bcrypt.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:postgres/postgres.dart';
import '../config/database_config.dart';
import '../models/perfil.dart';
import '../repositories/usuario_repository.dart';
import '../services/permisos_service.dart';
import '../services/sesion_service.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _repo = UsuarioRepository();
  final _picker = ImagePicker();

  bool _editando = false;
  bool _guardando = false;
  Perfil? _perfil;

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarImagen() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Foto de perfil'),
        content: const Text('¿Cómo deseas seleccionar la imagen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, ImageSource.camera), child: const Text('Cámara')),
          TextButton(onPressed: () => Navigator.pop(ctx, ImageSource.gallery), child: const Text('Galería')),
        ],
      ),
    );
    if (source == null || !mounted) return;

    final xfile = await _picker.pickImage(source: source, maxWidth: 512, maxHeight: 512);
    if (xfile == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final ext = p.extension(xfile.name);
    final dest = p.join(dir.path, 'profile_${_perfil!.id}$ext');
    final saved = await File(xfile.path).copy(dest);

    setState(() => _perfil = _perfil!.copyWith(fotoUrl: saved.path));
  }

  Future<void> _cargarPerfil() async {
    try {
      final conn = await Connection.open(Endpoint(
        host: DatabaseConfig.host,
        port: DatabaseConfig.port,
        database: DatabaseConfig.database,
        username: DatabaseConfig.username,
        password: DatabaseConfig.password,
      ), settings: const ConnectionSettings(sslMode: SslMode.disable));
      final filas = await conn.execute(Sql.named(
        'SELECT id, nombre, email, telefono, foto_url, rol, creado_en FROM usuarios WHERE id = @id',
      ), parameters: {'id': SesionService.usuarioId});
      await conn.close();
      final row = filas.isNotEmpty ? filas.first.toColumnMap() : null;
      if (row != null && mounted) {
        final perfil = Perfil(
          id: row['id'] as String,
          nombre: row['nombre'] as String,
          email: row['email'] as String?,
          telefono: row['telefono'] as String?,
          fotoUrl: row['foto_url'] as String?,
          rol: row['rol'] as String? ?? 'cliente',
          fechaRegistro: row['creado_en'] is DateTime
              ? row['creado_en'] as DateTime
              : DateTime.tryParse(row['creado_en'] as String? ?? ''),
        );
        setState(() => _perfil = perfil);
        _nombreCtrl.text = perfil.nombre;
        _emailCtrl.text = perfil.email ?? '';
        _telefonoCtrl.text = perfil.telefono ?? '';
        return;
      }
    } catch (_) {
      debugPrint('Perfil: Supabase no disponible');
    }

    final perfil = await _repo.obtenerPerfilActual();
    if (perfil != null && mounted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay conexión al servidor'), backgroundColor: Colors.orange),
        );
      }
      setState(() => _perfil = perfil);
      _nombreCtrl.text = perfil.nombre;
      _emailCtrl.text = perfil.email ?? '';
      _telefonoCtrl.text = perfil.telefono ?? '';
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final nombre = _nombreCtrl.text.trim();
    final email = _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim();
    final telefono = _telefonoCtrl.text.trim().isEmpty ? null : _telefonoCtrl.text.trim();

    var pgOk = false;

    try {
      final conn = await Connection.open(Endpoint(
        host: DatabaseConfig.host,
        port: DatabaseConfig.port,
        database: DatabaseConfig.database,
        username: DatabaseConfig.username,
        password: DatabaseConfig.password,
      ), settings: const ConnectionSettings(sslMode: SslMode.disable));
      await conn.execute(Sql.named(
        'UPDATE usuarios SET nombre = @nombre, email = @email, telefono = @telefono, foto_url = @foto_url WHERE id = @id',
      ), parameters: {
        'nombre': nombre,
        'email': email,
        'telefono': telefono,
        'foto_url': _perfil!.fotoUrl,
        'id': _perfil!.id,
      });
      await conn.close();
      pgOk = true;
    } catch (e) {
      debugPrint('Perfil: error Supabase — $e');
    }

    var localOk = true;
    try {
      final actualizado = _perfil!.copyWith(nombre: nombre, email: email, telefono: telefono, ultimaSincronizacion: DateTime.now());
      await SesionService.guardar(actualizado);
      if (mounted) setState(() { _perfil = actualizado; _editando = false; });
    } catch (e) {
      debugPrint('Perfil: error local — $e');
      localOk = false;
    }

    if (mounted) {
      setState(() => _guardando = false);
      if (pgOk && localOk) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado'), backgroundColor: Colors.green),
        );
      } else if (pgOk) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Servidor actualizado. Falló la copia local'), backgroundColor: Colors.orange),
        );
      } else if (localOk) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solo se guardó localmente. Sin conexión al servidor'), backgroundColor: Colors.orange),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al guardar (servidor y local)'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _cambiarContrasena() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final currentCtrl = TextEditingController();
        final newCtrl = TextEditingController();
        final confirmCtrl = TextEditingController();
        final formKey = GlobalKey<FormState>();
        var guardando = false;
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Cambiar contraseña'),
            content: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  controller: currentCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Contraseña actual', border: OutlineInputBorder()),
                  validator: (v) => v == null || v.isEmpty ? 'Ingresa tu contraseña actual' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: newCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Nueva contraseña', border: OutlineInputBorder()),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Ingresa la nueva contraseña';
                    if (v.length < 8) return 'Mínimo 8 caracteres';
                    if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Debe tener una mayúscula';
                    if (!RegExp(r'[a-z]').hasMatch(v)) return 'Debe tener una minúscula';
                    if (!RegExp(r'[0-9]').hasMatch(v)) return 'Debe tener un número';
                    if (!RegExp(r'[^a-zA-Z0-9\s]').hasMatch(v)) return 'Debe tener un carácter especial';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Confirmar contraseña', border: OutlineInputBorder()),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Confirma la contraseña';
                    if (v != newCtrl.text) return 'Las contraseñas no coinciden';
                    return null;
                  },
                ),
              ]),
            ),
            actions: [
              TextButton(onPressed: guardando ? null : () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: guardando ? null : () async {
                  if (!formKey.currentState!.validate()) return;
                  setDialogState(() => guardando = true);
                  try {
                    final conn = await Connection.open(Endpoint(
                      host: DatabaseConfig.host,
                      port: DatabaseConfig.port,
                      database: DatabaseConfig.database,
                      username: DatabaseConfig.username,
                      password: DatabaseConfig.password,
                    ));
                    final filas = await conn.execute(Sql.named(
                      'SELECT password_hash FROM usuarios WHERE id = @id',
                    ), parameters: {'id': _perfil!.id});
                    if (filas.isEmpty) {
                      await conn.close();
                      throw Exception('Usuario no encontrado');
                    }
                    final row = filas.first.toColumnMap();
                    final hash = row['password_hash'] as String?;
                    if (hash == null || !BCrypt.checkpw(currentCtrl.text, hash)) {
                      await conn.close();
                      if (ctx.mounted) {
                        setDialogState(() => guardando = false);
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Contraseña actual incorrecta'), backgroundColor: Colors.red),
                        );
                      }
                      return;
                    }
                    final newHash = BCrypt.hashpw(newCtrl.text, BCrypt.gensalt());
                    await conn.execute(Sql.named(
                      'UPDATE usuarios SET password_hash = @hash WHERE id = @id',
                    ), parameters: {'hash': newHash, 'id': _perfil!.id});
                    await conn.close();
                    if (ctx.mounted) {
                      Navigator.pop(ctx, true);
                    }
                  } catch (e) {
                    debugPrint('Perfil: error al cambiar contraseña — $e');
                    if (ctx.mounted) {
                      setDialogState(() => guardando = false);
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Error al cambiar la contraseña'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
                child: guardando
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Cambiar contraseña'),
              ),
            ],
          );
        });
      },
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _confirmarCerrarSesion() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de cerrar sesión?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cerrar sesión', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await SesionService.cerrarSesion();
      if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (PermisosService.esInvitado) {
      return Scaffold(
        appBar: AppBar(title: const Text('Perfil')),
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.lock_outline, size: 64, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            const Text('Debe autenticarse para entrar a esta página', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false), child: const Text('Iniciar sesión')),
          ]),
        ),
      );
    }
    final theme = Theme.of(context);
    final u = SesionService.usuario;
    final inicial = u.nombre.isNotEmpty ? u.nombre[0].toUpperCase() : '?';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          if (_editando) ...[
            TextButton(onPressed: () {
              setState(() => _editando = false);
              _nombreCtrl.text = _perfil?.nombre ?? u.nombre;
              _emailCtrl.text = _perfil?.email ?? u.email ?? '';
              _telefonoCtrl.text = _perfil?.telefono ?? u.telefono ?? '';
            }, child: const Text('Cancelar')),
            TextButton(onPressed: _guardando ? null : _guardar, child: _guardando
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Guardar')),
          ] else
            IconButton(icon: const Icon(Icons.edit), onPressed: () => setState(() => _editando = true)),
        ],
      ),
      body: _perfil == null
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(children: [
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _editando ? _seleccionarImagen : null,
                    child: Stack(children: [
                      CircleAvatar(radius: 50, backgroundColor: theme.primaryColor,
                        backgroundImage: _perfil!.fotoUrl != null && File(_perfil!.fotoUrl!).existsSync()
                            ? FileImage(File(_perfil!.fotoUrl!))
                            : null,
                        child: _perfil!.fotoUrl == null || !File(_perfil!.fotoUrl!).existsSync()
                            ? Text(inicial, style: const TextStyle(fontSize: 40, color: Colors.white))
                            : null),
                      if (_editando)
                        Positioned(bottom: 0, right: 0, child: CircleAvatar(radius: 16,
                          backgroundColor: theme.primaryColor,
                          child: const Icon(Icons.camera_alt, size: 16, color: Colors.white))),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  if (_editando) ...[
                    TextFormField(controller: _nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
                      validator: (v) => v == null || v.trim().isEmpty ? 'El nombre es obligatorio' : null),
                    const SizedBox(height: 12),
                    TextFormField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Correo electrónico', border: OutlineInputBorder()),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => v != null && v.isNotEmpty && !v.contains('@') ? 'Correo inválido' : null),
                    const SizedBox(height: 12),
                    TextFormField(controller: _telefonoCtrl, decoration: const InputDecoration(labelText: 'Teléfono', border: OutlineInputBorder()),
                      keyboardType: TextInputType.phone),
                  ] else ...[
                    Text(u.nombre, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: u.esAdmin ? Colors.amber.withValues(alpha: 0.2) : theme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12)),
                      child: Text(u.esAdmin ? 'Administrador' : 'Cliente',
                          style: TextStyle(fontSize: 12, color: u.esAdmin ? Colors.amber[800] : theme.primaryColor, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 24),
                    _InfoCard(theme, Icons.email_outlined, 'Correo electrónico', u.email ?? 'No registrado'),
                    const SizedBox(height: 8),
                    _InfoCard(theme, Icons.phone_outlined, 'Teléfono', u.telefono ?? 'No registrado'),
                    if (_perfil!.fechaRegistro != null) ...[
                      const SizedBox(height: 8),
                      _InfoCard(theme, Icons.calendar_today, 'Miembro desde', _formatearFecha(_perfil!.fechaRegistro!)),
                    ],
                  ],
                  const SizedBox(height: 32),
                  SizedBox(width: double.infinity, child: OutlinedButton.icon(
                    onPressed: _cambiarContrasena,
                    icon: const Icon(Icons.lock_outline, size: 18),
                    label: const Text('Cambiar contraseña'),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  )),
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity, child: OutlinedButton.icon(
                    onPressed: _confirmarCerrarSesion,
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Cerrar sesión'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                  )),
                ]),
              ),
            ),
    );
  }

  String _formatearFecha(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _InfoCard extends StatelessWidget {
  final ThemeData theme;
  final IconData icono;
  final String label;
  final String valor;

  const _InfoCard(this.theme, this.icono, this.label, this.valor);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(icono, size: 22, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
          const SizedBox(height: 2),
          Text(valor, style: const TextStyle(fontSize: 15)),
        ]),
      ]),
    );
  }
}
