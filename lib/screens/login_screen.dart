import 'dart:convert';
import 'dart:io';
import 'package:bcrypt/bcrypt.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:postgres/postgres.dart';
import '../database/pg_connection.dart';
import '../database/database_helper.dart';
import '../models/perfil.dart';
import '../services/sesion_service.dart';
import 'pantalla_principal.dart';
import 'privacidad_screen.dart';
import 'terminos_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmarPasswordCtrl = TextEditingController();

  bool _esRegistro = false;
  bool _verPassword = false;
  bool _cargando = false;
  bool _recordarContrasena = false;
  bool _aceptaTerminos = false;

  // Mapa en memoria para códigos de recuperación (email → {código, expiración})
  // En producción, sustituir por almacenamiento en PostgreSQL + envío por SMTP
  static final Map<String, Map<String, dynamic>> _codigosRecuperacion = {};

  @override
  void initState() {
    super.initState();
    _cargarCredencialesGuardadas();
  }

  Future<void> _cargarCredencialesGuardadas() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('recordar_email');
    final password = prefs.getString('recordar_password');
    if (email != null && password != null) {
      _emailCtrl.text = email;
      _passwordCtrl.text = password;
      setState(() => _recordarContrasena = true);
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmarPasswordCtrl.dispose();
    super.dispose();
  }

  // Supabase
  static const String _supabaseRestUrl = 'https://sicgkowisuxzxuctzfry.supabase.co/rest/v1';
  static const String _supabaseEdgeUrl = 'https://sicgkowisuxzxuctzfry.supabase.co/functions/v1/send-reset-code';
  static const String _supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNpY2drb3dpc3V4enh1Y3R6ZnJ5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI0MTg5MTksImV4cCI6MjA5Nzk5NDkxOX0.qO6HGwRCpk-_0cuFJvSEW-bUk2DNUeS71UwvozNpLg0';

  Future<void> _iniciarSesion() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);

    try {
      final email = _emailCtrl.text.trim();
      final password = _passwordCtrl.text;
      Perfil? perfil;

      try {
        final conn = await abrirConexionPostgres();
        final filas = await conn.execute(Sql.named('SELECT * FROM usuarios WHERE email = @email'), parameters: {'email': email});
        await conn.close();
        if (filas.isEmpty) {
          _mostrarError('Correo no registrado');
          return;
        }
        final row = filas.first.toColumnMap();
        if (!BCrypt.checkpw(password, row['password_hash'] as String)) {
          _mostrarError('Contraseña incorrecta');
          return;
        }

        perfil = Perfil(
          id: row['id'] as String,
          nombre: row['nombre'] as String? ?? '',
          email: row['email'] as String? ?? email,
          telefono: row['telefono'] as String?,
          fotoUrl: row['foto_url'] as String?,
          passwordHash: row['password_hash'] as String?,
          rol: row['rol'] as String? ?? 'cliente',
          fechaRegistro: row['creado_en'] is DateTime
              ? row['creado_en'] as DateTime
              : DateTime.tryParse(row['creado_en'] as String? ?? ''),
        );
      } catch (e) {
        debugPrint('LOGIN: fallo conexión Postgres local: $e');

        final db = await DatabaseHelper.database;
        final filas = await db.query('usuario', where: 'email = ?', whereArgs: [email]);

        if (filas.isEmpty) {
          _mostrarError('Sin conexión al servidor. No hay datos guardados localmente para este correo.');
          return;
        }

        final local = Perfil.fromMap(filas.first);
        if (local.passwordHash == null || !BCrypt.checkpw(password, local.passwordHash!)) {
          _mostrarError('Sin conexión al servidor y la contraseña local no coincide. Conéctate a internet para iniciar sesión.');
          return;
        }

        perfil = local;
      }

      await SesionService.guardar(perfil);

      final prefs = await SharedPreferences.getInstance();
      if (_recordarContrasena) {
        await prefs.setString('recordar_email', email);
        await prefs.setString('recordar_password', password);
      } else {
        await prefs.remove('recordar_email');
        await prefs.remove('recordar_password');
      }

      if (mounted) _navegarAPrincipal();
    } catch (e) {
      debugPrint('LOGIN: excepción: $e');
      _mostrarError('Error inesperado al iniciar sesión');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_aceptaTerminos) {
      _mostrarError('Debes aceptar los términos y condiciones');
      return;
    }
    setState(() => _cargando = true);

    try {
      final email = _emailCtrl.text.trim();
      final nombre = _nombreCtrl.text.trim();
      final telefono = _telefonoCtrl.text.trim();

      final hash = BCrypt.hashpw(_passwordCtrl.text, BCrypt.gensalt());
      final conn = await abrirConexionPostgres();
      await conn.execute(Sql.named(
        'INSERT INTO usuarios (id, nombre, email, telefono, password_hash) VALUES (@id, @nombre, @email, @telefono, @hash)',
      ), parameters: {
        'id': const Uuid().v4(),
        'nombre': nombre,
        'email': email,
        'telefono': telefono,
        'hash': hash,
      });
      await conn.close();

      if (!mounted) return;
      setState(() => _esRegistro = false);
      _passwordCtrl.clear();
      _confirmarPasswordCtrl.clear();
      _aceptaTerminos = false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Registro exitoso. Ahora puedes iniciar sesión.'), backgroundColor: Colors.green.shade700),
      );
    } catch (e) {
      debugPrint('REGISTRO: excepción: $e');
      _mostrarError('Error al registrarse. Verifica tu conexión a internet.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _entrarComoInvitado() async {
    final guest = Perfil(
      id: const Uuid().v4(),
      nombre: 'Invitado',
      rol: 'invitado',
      fechaRegistro: DateTime.now(),
    );
    SesionService.iniciarSesionLocal(guest);
    if (mounted) _navegarAPrincipal();
  }

  void _mostrarRecuperarContrasena() {
    final emailCtrl = TextEditingController();
    final codigoCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var paso = 1; // 1=email, 2=código, 3=nueva contraseña
    var cargando = false;
    var emailVerificado = '';
    var intentosFallidos = 0;
    var bloqueadoHasta = DateTime.now();
    var fortaleza = 0.0;
    var codigoGenerado = '';

    // Mapa estático compartido por todas las instancias (dev)
    // En producción: guardar en PostgreSQL con TIMESTAMP de expiración
    final codigosApp = _codigosRecuperacion;

    String? _validarPassword(String? v) {
      if (v == null || v.isEmpty) return 'Ingresa tu contraseña';
      if (v.length < 8) return 'Mínimo 8 caracteres';
      if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Debe tener una mayúscula';
      if (!RegExp(r'[a-z]').hasMatch(v)) return 'Debe tener una minúscula';
      if (!RegExp(r'[0-9]').hasMatch(v)) return 'Debe tener un número';
      if (!RegExp(r'[^a-zA-Z0-9\s]').hasMatch(v)) return 'Debe tener un carácter especial';
      return null;
    }

    double _calcularFortaleza(String v) {
      var score = 0.0;
      if (v.length >= 8) score += 0.2;
      if (v.length >= 12) score += 0.15;
      if (RegExp(r'[A-Z]').hasMatch(v)) score += 0.2;
      if (RegExp(r'[a-z]').hasMatch(v)) score += 0.15;
      if (RegExp(r'[0-9]').hasMatch(v)) score += 0.15;
      if (RegExp(r'[^a-zA-Z0-9\s]').hasMatch(v)) score += 0.15;
      return score.clamp(0.0, 1.0);
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(paso == 1 ? 'Recuperar contraseña' : paso == 2 ? 'Código de verificación' : 'Nueva contraseña'),
              content: Form(
                key: formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: SizedBox(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (paso == 1)
                        TextFormField(
                          controller: emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: 'Correo electrónico', prefixIcon: Icon(Icons.email_outlined)),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Ingresa tu correo';
                            if (!v.contains('@')) return 'Correo inválido';
                            return null;
                          },
                        ),
                      if (paso == 2) ...[
                        Text('Hemos enviado un código de 6 dígitos a $emailVerificado',
                            style: const TextStyle(fontSize: 13), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: codigoCtrl,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 24, letterSpacing: 8),
                          decoration: const InputDecoration(
                            labelText: 'Código',
                            counterText: '',
                            prefixIcon: Icon(Icons.pin_outlined),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Ingresa el código';
                            if (v.trim().length < 6) return 'El código debe tener 6 dígitos';
                            return null;
                          },
                        ),
                      ],
                      if (paso == 3) ...[
                        TextFormField(
                          controller: newPasswordCtrl,
                          obscureText: true,
                          onChanged: (v) => setDialogState(() => fortaleza = _calcularFortaleza(v)),
                          decoration: InputDecoration(
                            labelText: 'Nueva contraseña',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: newPasswordCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close, size: 18),
                                    onPressed: () { newPasswordCtrl.clear(); setDialogState(() => fortaleza = 0); },
                                  )
                                : null,
                          ),
                          validator: _validarPassword,
                        ),
                        if (newPasswordCtrl.text.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: fortaleza,
                              minHeight: 6,
                              backgroundColor: Colors.grey.shade300,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                fortaleza < 0.4 ? Colors.red
                                    : fortaleza < 0.7 ? Colors.orange
                                    : Colors.green,
                              ),
                            ),
                          ),
                          Text(
                            fortaleza < 0.4 ? 'Débil'
                                : fortaleza < 0.7 ? 'Media'
                                : 'Fuerte',
                            style: TextStyle(fontSize: 11, color: fortaleza < 0.4 ? Colors.red
                                : fortaleza < 0.7 ? Colors.orange
                                : Colors.green),
                          ),
                        ],
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: confirmPasswordCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Confirmar contraseña', prefixIcon: Icon(Icons.lock_outline)),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Confirma tu contraseña';
                            if (v != newPasswordCtrl.text) return 'Las contraseñas no coinciden';
                            return null;
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: cargando ? null : () { codigosApp.remove(emailVerificado); Navigator.pop(ctx); }, child: const Text('Cancelar')),
                if (paso == 1 && DateTime.now().isBefore(bloqueadoHasta))
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Text('Reintenta en ${bloqueadoHasta.difference(DateTime.now()).inSeconds}s',
                        style: const TextStyle(color: Colors.red, fontSize: 12)),
                  )
                else
                  ElevatedButton(
                    onPressed: cargando ? null : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => cargando = true);

                      try {
                        if (paso == 1) {
                          // Verificar email en Supabase
                          final email = emailCtrl.text.trim();
                          final resp = await http.get(
                            Uri.parse('$_supabaseRestUrl/usuarios?email=eq.${Uri.encodeQueryComponent(email)}&select=id'),
                            headers: {
                              'apikey': _supabaseAnonKey,
                              'Authorization': 'Bearer $_supabaseAnonKey',
                            },
                          ).timeout(const Duration(seconds: 10));

                          if (resp.statusCode != 200 || (jsonDecode(resp.body) as List).isEmpty) {
                            intentosFallidos++;
                            if (intentosFallidos >= 3) {
                              bloqueadoHasta = DateTime.now().add(const Duration(seconds: 30));
                            }
                            if (ctx.mounted) {
                              setDialogState(() { cargando = false; });
                              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                content: Text(intentosFallidos >= 3
                                    ? 'Demasiados intentos. Espera 30 segundos.'
                                    : 'Este correo no está registrado. Intento ${intentosFallidos}/3'),
                                backgroundColor: Colors.red,
                              ));
                            }
                            return;
                          }
                          intentosFallidos = 0;
                          emailVerificado = email;

                          codigoGenerado = DateTime.now().microsecondsSinceEpoch.toString().substring(10, 16);
                          codigosApp[emailVerificado] = {
                            'codigo': codigoGenerado,
                            'expiracion': DateTime.now().add(const Duration(minutes: 10)),
                          };

                          try {
                            final httpClient = HttpClient()
                              ..connectionTimeout = const Duration(seconds: 15);
                            final request = await httpClient.postUrl(Uri.parse(_supabaseEdgeUrl));
                            request.headers.contentType = ContentType.json;
                            request.headers.set('Authorization', 'Bearer $_supabaseAnonKey');
                            request.write(jsonEncode({
                              'email': emailVerificado,
                              'codigo': codigoGenerado,
                            }));
                            final edgeResp = await request.close();
                            final statusCode = edgeResp.statusCode;
                            final body = await edgeResp.transform(utf8.decoder).join();
                            httpClient.close();
                            if (statusCode != 200) {
                              debugPrint('RECUPERAR: Edge Function error $statusCode: $body');
                              if (ctx.mounted) {
                                setDialogState(() => cargando = false);
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(content: Text('Fallo en la conexión al servidor'), backgroundColor: Colors.red),
                                );
                              }
                              return;
                            }
                          } catch (e) {
                            debugPrint('RECUPERAR: Error llamando Edge Function: $e');
                            if (ctx.mounted) {
                              setDialogState(() => cargando = false);
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(content: Text('Fallo en la conexión al servidor'), backgroundColor: Colors.red),
                              );
                            }
                            return;
                          }

                          if (ctx.mounted) {
                            setDialogState(() { paso = 2; cargando = false; });
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                              content: Text('Código enviado a $emailVerificado'),
                              backgroundColor: Colors.green.shade700,
                            ));
                          }
                        } else if (paso == 2) {
                          // Verificar código
                          final data = codigosApp[emailVerificado];
                          if (data == null) {
                            if (ctx.mounted) {
                              setDialogState(() => cargando = false);
                              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                                content: Text('Código no encontrado. Solicita uno nuevo.'),
                                backgroundColor: Colors.red,
                              ));
                            }
                            return;
                          }
                          if (DateTime.now().isAfter(data['expiracion'] as DateTime)) {
                            codigosApp.remove(emailVerificado);
                            if (ctx.mounted) {
                              setDialogState(() { paso = 1; cargando = false; });
                              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                                content: Text('El código ha expirado. Solicita uno nuevo.'),
                                backgroundColor: Colors.red,
                              ));
                            }
                            return;
                          }
                          if (codigoCtrl.text.trim() != data['codigo'] as String) {
                            if (ctx.mounted) {
                              setDialogState(() => cargando = false);
                              ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                                content: Text('Código incorrecto'),
                                backgroundColor: Colors.red,
                              ));
                            }
                            return;
                          }
                          codigosApp.remove(emailVerificado);
                          setDialogState(() { paso = 3; cargando = false; });
                        } else {
                          // Actualizar contraseña en Supabase
                          final passwordHash = BCrypt.hashpw(newPasswordCtrl.text, BCrypt.gensalt());
                          final patchResp = await http.patch(
                            Uri.parse('$_supabaseRestUrl/usuarios?email=eq.${Uri.encodeQueryComponent(emailVerificado)}'),
                            headers: {
                              'apikey': _supabaseAnonKey,
                              'Authorization': 'Bearer $_supabaseAnonKey',
                              'Content-Type': 'application/json',
                              'Prefer': 'return=minimal',
                            },
                            body: jsonEncode({
                              'password_hash': passwordHash,
                              'actualizado_en': DateTime.now().toUtc().toIso8601String(),
                            }),
                          ).timeout(const Duration(seconds: 10));

                          if (patchResp.statusCode != 204 && patchResp.statusCode != 200) {
                            throw Exception('Error de Supabase: ${patchResp.statusCode}');
                          }

                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            _emailCtrl.text = emailVerificado;
                            _passwordCtrl.text = newPasswordCtrl.text;
                            setState(() => _recordarContrasena = true);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Contraseña actualizada. Ahora puedes iniciar sesión.'), backgroundColor: Colors.green),
                            );
                          }
                        }
                      } catch (e) {
                        debugPrint('RECUPERAR: excepción: $e');
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Error de conexión al servidor'), backgroundColor: Colors.red),
                          );
                        }
                      } finally {
                        if (ctx.mounted) setDialogState(() => cargando = false);
                      }
                    },
                    child: Text(paso == 1 ? 'Enviar código' : paso == 2 ? 'Verificar' : 'Actualizar'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  TapGestureRecognizer _tapTerminos() {
    return TapGestureRecognizer()..onTap = () {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const TerminosScreen()));
    };
  }

  TapGestureRecognizer _tapPrivacidad() {
    return TapGestureRecognizer()..onTap = () {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacidadScreen()));
    };
  }

  void _navegarAPrincipal() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const PantallaPrincipal(),
        transitionsBuilder: (_, __, ___, child) => child,
        transitionDuration: Duration.zero,
      ),
    );
  }

  void _mostrarError(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje), backgroundColor: Colors.red.shade700));
    setState(() => _cargando = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final esOscuro = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: esOscuro ? theme.scaffoldBackgroundColor : const Color(0xFFF7F8FC),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 240,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0A2E6E), Color(0xFF1245A8), Color(0xFF1E6FE8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  Image.asset('assets/images/logo_name_down_white.png', height: 100, fit: BoxFit.contain),
                  const SizedBox(height: 12),
                  Text('Negocios cerca de ti', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14, fontWeight: FontWeight.w500)),
                  const Spacer(flex: 3),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: esOscuro ? const Color(0xFF2A2A3E) : const Color(0xFFEAECF4),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          _TabButton(label: 'Iniciar sesión', activo: !_esRegistro, esOscuro: esOscuro,
                              onTap: () { _formKey.currentState?.reset(); setState(() => _esRegistro = false); }),
                          _TabButton(label: 'Registrarse', activo: _esRegistro, esOscuro: esOscuro,
                              onTap: () { _formKey.currentState?.reset(); setState(() => _esRegistro = true); }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (_esRegistro) ...[
                      _Campo(label: 'Nombre completo', icono: Icons.person_outline_rounded, tipo: TextInputType.name, esOscuro: esOscuro, controlador: _nombreCtrl,
                          validador: (v) {
                            if (v == null || v.trim().isEmpty) return 'Ingresa tu nombre';
                            if (v.trim().length < 3) return 'Mínimo 3 caracteres';
                            return null;
                          }),
                      const SizedBox(height: 14),
                      _Campo(label: 'Teléfono', icono: Icons.phone_outlined, tipo: TextInputType.phone, esOscuro: esOscuro, controlador: _telefonoCtrl,
                          validador: (v) {
                            if (v != null && v.trim().isNotEmpty && !RegExp(r'^\+?\d{7,15}$').hasMatch(v.trim())) return 'Teléfono inválido';
                            return null;
                          }),
                      const SizedBox(height: 14),
                    ],
                    _Campo(label: 'Correo electrónico', icono: Icons.email_outlined, tipo: TextInputType.emailAddress, esOscuro: esOscuro, controlador: _emailCtrl,
                        validador: (v) {
                          if (v == null || v.trim().isEmpty) return 'Ingresa tu correo';
                          if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) return 'Correo inválido';
                          return null;
                        }),
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(
                        color: esOscuro ? const Color(0xFF1E1E32) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: esOscuro ? const Color(0xFF2A2A3E) : const Color(0xFFEAECF4)),
                      ),
                      child: TextFormField(
                        controller: _passwordCtrl,
                        obscureText: !_verPassword,
                        keyboardType: TextInputType.visiblePassword,
                        style: TextStyle(color: theme.colorScheme.onSurface),
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          labelStyle: TextStyle(color: esOscuro ? const Color(0xFF9E9E9E) : const Color(0xFF6B7280)),
                          prefixIcon: Icon(Icons.lock_outline_rounded, color: esOscuro ? const Color(0xFF9E9E9E) : const Color(0xFF6B7280)),
                          suffixIcon: IconButton(
                            icon: Icon(_verPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: esOscuro ? const Color(0xFF9E9E9E) : const Color(0xFF6B7280), size: 20),
                            onPressed: () => setState(() => _verPassword = !_verPassword),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Ingresa tu contraseña';
                          if (v.length < 8) return 'Mínimo 8 caracteres';
                          return null;
                        },
                      ),
                    ),
                    if (_esRegistro) ...[
                      const SizedBox(height: 14),
                      Container(
                        decoration: BoxDecoration(
                          color: esOscuro ? const Color(0xFF1E1E32) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: esOscuro ? const Color(0xFF2A2A3E) : const Color(0xFFEAECF4)),
                        ),
                        child: TextFormField(
                          controller: _confirmarPasswordCtrl,
                          obscureText: !_verPassword,
                          keyboardType: TextInputType.visiblePassword,
                          style: TextStyle(color: theme.colorScheme.onSurface),
                          decoration: InputDecoration(
                            labelText: 'Confirmar contraseña',
                            labelStyle: TextStyle(color: esOscuro ? const Color(0xFF9E9E9E) : const Color(0xFF6B7280)),
                            prefixIcon: Icon(Icons.lock_outline_rounded, color: esOscuro ? const Color(0xFF9E9E9E) : const Color(0xFF6B7280)),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Confirma tu contraseña';
                            if (v != _passwordCtrl.text) return 'Las contraseñas no coinciden';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: _aceptaTerminos,
                              onChanged: (v) => setState(() => _aceptaTerminos = v ?? false),
                              activeColor: theme.colorScheme.primary,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(fontSize: 12, color: esOscuro ? const Color(0xFF9E9E9E) : const Color(0xFF6B7280)),
                                children: [
                                  TextSpan(text: 'Acepto los '),
                                  TextSpan(
                                    text: 'Términos y condiciones',
                                    style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                                    recognizer: _tapTerminos(),
                                  ),
                                  TextSpan(text: ' y la '),
                                  TextSpan(
                                    text: 'Política de privacidad',
                                    style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                                    recognizer: _tapPrivacidad(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (!_esRegistro) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: _recordarContrasena,
                              onChanged: (v) => setState(() => _recordarContrasena = v ?? false),
                              activeColor: theme.colorScheme.primary,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _recordarContrasena = !_recordarContrasena),
                            child: Text('Recordar contraseña', style: TextStyle(fontSize: 13, color: esOscuro ? const Color(0xFF9E9E9E) : const Color(0xFF6B7280))),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: _mostrarRecuperarContrasena,
                            style: TextButton.styleFrom(foregroundColor: theme.colorScheme.primary, padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                            child: Text('¿Olvidaste tu contraseña?', style: TextStyle(fontSize: 13, color: theme.colorScheme.primary)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                    ],
                    SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _cargando ? null : (_esRegistro ? _registrar : _iniciarSesion),
                        style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        child: _cargando
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(_esRegistro ? 'Crear cuenta' : 'Iniciar sesión', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(child: Divider(color: esOscuro ? const Color(0xFF2A2A3E) : const Color(0xFFEAECF4), thickness: 1)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text('o', style: TextStyle(color: esOscuro ? const Color(0xFF9E9E9E) : Colors.grey[400], fontSize: 13)),
                        ),
                        Expanded(child: Divider(color: esOscuro ? const Color(0xFF2A2A3E) : const Color(0xFFEAECF4), thickness: 1)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 54,
                      child: OutlinedButton.icon(
                        onPressed: _cargando ? null : _entrarComoInvitado,
                        icon: Icon(Icons.explore_outlined, size: 20, color: theme.colorScheme.primary),
                        label: Text('Explorar sin cuenta', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: theme.colorScheme.primary)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.primary,
                          side: BorderSide(color: esOscuro ? const Color(0xFF2A2A3E) : const Color(0xFFEAECF4), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ));
  }
}

class _TabButton extends StatelessWidget {
  final String label; final bool activo; final bool esOscuro; final VoidCallback onTap;
  const _TabButton({required this.label, required this.activo, required this.esOscuro, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: activo ? (esOscuro ? const Color(0xFF1A1A2E) : Colors.white) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: activo ? [BoxShadow(color: Colors.black.withValues(alpha: esOscuro ? 0.3 : 0.08), blurRadius: 8, offset: const Offset(0, 2))] : [],
          ),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(
            fontSize: 14, fontWeight: activo ? FontWeight.w600 : FontWeight.w400,
            color: activo ? (esOscuro ? Colors.white : const Color(0xFF1245A8)) : (esOscuro ? const Color(0xFF9E9E9E) : const Color(0xFF6B7280)),
          )),
        ),
      ),
    );
  }
}

class _Campo extends StatelessWidget {
  final String label; final IconData icono; final TextInputType tipo; final bool esOscuro;
  final TextEditingController? controlador; final String? Function(String?)? validador;
  const _Campo({required this.label, required this.icono, required this.tipo, required this.esOscuro, this.controlador, this.validador});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: esOscuro ? const Color(0xFF1E1E32) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: esOscuro ? const Color(0xFF2A2A3E) : const Color(0xFFEAECF4)),
      ),
      child: TextFormField(
        controller: controlador,
        keyboardType: tipo,
        validator: validador,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: esOscuro ? const Color(0xFF9E9E9E) : const Color(0xFF6B7280)),
          prefixIcon: Icon(icono, color: esOscuro ? const Color(0xFF9E9E9E) : const Color(0xFF6B7280)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}
