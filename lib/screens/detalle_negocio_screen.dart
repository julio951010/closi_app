import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:uuid/uuid.dart';
import 'package:postgres/postgres.dart';
import '../database/pg_connection.dart';
import '../database/favorito_dao.dart';
import '../database/negocio_dao.dart';
import '../database/opinion_dao.dart';
import '../database/producto_servicio_dao.dart';
import '../models/favorito.dart';
import '../models/negocio.dart';
import '../models/opinion.dart';
import '../models/producto_servicio.dart';
import '../services/negocio_service.dart';
import '../services/permisos_service.dart';
import '../services/sesion_service.dart';
import '../services/sync_service.dart';
import 'como_llegar_screen.dart';
import 'opiniones_list_screen.dart';

class DetalleNegocioScreen extends StatefulWidget {
  final Negocio negocio;

  const DetalleNegocioScreen({super.key, required this.negocio});

  @override
  State<DetalleNegocioScreen> createState() => _DetalleNegocioScreenState();
}

class _DetalleNegocioScreenState extends State<DetalleNegocioScreen> {
  final NegocioDao _negocioDao = NegocioDao();
  final ProductoServicioDao _productoDao = ProductoServicioDao();
  final OpinionDao _opinionDao = OpinionDao();
  final FavoritoDao _favoritoDao = FavoritoDao();
  late Negocio _negocio;
  late bool _esFavorito;
  List<ProductoServicio> _productos = [];
  List<Opinion> _opiniones = [];
  bool _cargandoOpiniones = true;

  @override
  void initState() {
    super.initState();
    _negocio = widget.negocio;
    _esFavorito = _negocio.esFavorito;
    _refreshNegocio();
    _cargarProductos();
    _cargarOpiniones();
  }

  Future<void> _refreshNegocio() async {
    final actualizado = await _negocioDao.obtenerPorId(_negocio.id);
    if (actualizado != null && mounted) setState(() => _negocio = actualizado);
  }

  Future<void> _cargarProductos() async {
    final n = _negocio;
    try {
      final items = n.origen == 'propio'
          ? await _productoDao.obtenerPorNegocio(n.id)
          : await NegocioService.consultarProductos(n.id);
      if (mounted) setState(() => _productos = items);
    } catch (_) {}
  }

  Future<void> _cargarOpiniones() async {
    final n = _negocio;
    try {
      final locales = await _opinionDao.obtenerPorNegocio(n.id);
      List<Opinion> remotas = [];
      if (n.origen != 'propio') {
        remotas = await NegocioService.consultarOpiniones(n.id);
      }
      final ids = locales.map((r) => r.id).toSet();
      final fusion = <Opinion>[...locales, ...remotas.where((r) => !ids.contains(r.id))];
      if (mounted) setState(() { _opiniones = fusion; _cargandoOpiniones = false; });
    } catch (_) {
      if (mounted) setState(() => _cargandoOpiniones = false);
    }
  }

  Future<void> _toggleFavorito() async {
    if (!PermisosService.puedeFavorito) {
      PermisosService.mostrarSnackbarAutenticacion(context);
      return;
    }
    final nuevoEstado = !_esFavorito;
    setState(() => _esFavorito = nuevoEstado);
    try {
      if (nuevoEstado) {
        await _favoritoDao.agregar(Favorito(
          id: const Uuid().v4(),
          usuarioId: SesionService.usuarioId,
          negocioId: _negocio.id,
          fecha: DateTime.now(),
        ));
      } else {
        await _favoritoDao.quitar(SesionService.usuarioId, _negocio.id);
      }
      unawaited(SyncService.sincronizar());
    } catch (e) {
      setState(() => _esFavorito = !nuevoEstado);
    }
  }

  Future<void> _abrirRatingModal() async {
    if (!PermisosService.puedeCalificar) {
      PermisosService.mostrarSnackbarAutenticacion(context);
      return;
    }
    final result = await showModalBottomSheet<int>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _RatingModal(calificacionActual: 0),
    );
    if (result == null || result <= 0) return;
    try {
      final conn = await abrirConexionPostgres();
      try {
        await conn.execute(
          Sql.named('''
            INSERT INTO calificaciones (id, usuario_id, negocio_id, calificacion, creado_en)
            VALUES (@id, @usuarioId, @negocioId, @calificacion, NOW())
            ON CONFLICT (usuario_id, negocio_id) DO UPDATE SET calificacion = @calificacion, creado_en = NOW()
          '''),
          parameters: {
            'id': const Uuid().v4(),
            'usuarioId': SesionService.usuarioId,
            'negocioId': _negocio.id,
            'calificacion': result,
          },
        );
      } finally {
        await conn.close();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Calificación guardada'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Error al guardar calificación: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al guardar calificación'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _abrirOpinionModal({Opinion? existente}) async {
    if (!PermisosService.puedeOpinar) {
      PermisosService.mostrarSnackbarAutenticacion(context);
      return;
    }
    final result = await showModalBottomSheet<Opinion>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _OpinionModal(negocioId: _negocio.id, existente: existente),
    );
    if (result == null) return;
    final conn = await abrirConexionPostgres();
    try {
      await conn.execute(
        Sql.named('''
          INSERT INTO opiniones (id, usuario_id, negocio_id, comentario, anonimo, fecha, nombre_usuario)
          VALUES (@id, @usuarioId, @negocioId, @comentario, @anonimo, @fecha, @nombreUsuario)
        '''),
        parameters: {
          'id': result.id,
          'usuarioId': result.usuarioId,
          'negocioId': result.negocioId,
          'comentario': result.comentario,
          'anonimo': result.anonimo,
          'fecha': result.fecha,
          'nombreUsuario': result.nombreUsuario,
        },
      );
    } finally {
      await conn.close();
    }
    unawaited(SyncService.sincronizar());
    await _cargarOpiniones();
  }

  @override
  Widget build(BuildContext context) {
    final n = _negocio;
    return Scaffold(
      appBar: AppBar(
        title: Text(n.nombre, style: const TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            icon: Icon(_esFavorito ? Icons.favorite : Icons.favorite_border, color: _esFavorito ? Colors.red : null),
            onPressed: _toggleFavorito,
          ),
        ],
      ),
      body: DefaultTabController(
        length: 2,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerScrolled) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: _buildCabecera(n),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                tabBar: TabBar(
                  labelColor: Theme.of(context).colorScheme.onSurface,
                  unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  indicatorColor: Theme.of(context).primaryColor,
                  tabs: const [
                    Tab(text: 'Información'),
                    Tab(text: 'Productos y servicios'),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (n.descripcion != null && n.descripcion!.isNotEmpty) ...[
                      Text(n.descripcion!, style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), height: 1.5)),
                      const Divider(height: 32),
                    ],
                    _buildHorario(n),
                    if (n.horario != null) const Divider(height: 32),
                    _buildContacto(n),
                    const Divider(height: 32),
                    _buildUbicacion(n),
                    if (n.lat != 0 || n.lon != 0) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => ComoLlegarScreen(negocio: n),
                          )),
                          icon: const Icon(Icons.directions),
                          label: const Text('Cómo llegar'),
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                        ),
                      ),
                    ],
                    const Divider(height: 32),
                    _buildOpiniones(n),
                    // Bottom clearance for safe area
                    SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
                  ],
                ),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                child: _productos.isEmpty
                    ? Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 48), child: Column(children: [
                        Icon(Icons.shopping_bag_outlined, size: 56, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        Text('No hay productos o servicios registrados', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
                      ])))
                    : _buildProductos(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCabecera(Negocio n) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: double.infinity, height: 160,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: n.fotos.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(File(n.fotos.first), fit: BoxFit.cover,
                          width: double.infinity, height: 160,
                          errorBuilder: (_, __, ___) => _iconoCentro(n)),
                    )
                  : _iconoCentro(n),
            ),
            if (n.esDestacado)
              Positioned(top: 8, left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.amber[700], borderRadius: BorderRadius.circular(12)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.star, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text('Destacado', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ]),
                ),
              ),
            if (n.origen == 'propio')
              Positioned(top: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.blue[700], borderRadius: BorderRadius.circular(12)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.verified, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text('Dueño', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ]),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(n.nombre, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildCategoriaBadge(n),
            const Spacer(),
            GestureDetector(
              onTap: _abrirRatingModal,
              child: Row(
                children: [
                  Icon(
                    (n.calificacion ?? 0) > 0 ? Icons.star : Icons.star_border,
                    color: Theme.of(context).colorScheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    (n.calificacion ?? 0) > 0 ? (n.calificacion ?? 0).toStringAsFixed(1) : '0.0',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                  ),
                  if ((n.totalResenas ?? 0) > 0) ...[
                    const SizedBox(width: 4),
                    Text('(${n.totalResenas})', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 14)),
                  ],
                ],
              ),
            ),
          ],
        ),
        if (n.distancia != null)
          Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [
            Icon(Icons.my_location, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
            const SizedBox(width: 4),
            Text('A ${n.distancia!.toStringAsFixed(1)} km', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
          ])),
      ],
    );
  }

  Widget _buildCategoriaBadge(Negocio n) {
    final theme = Theme.of(context);
    final esOscuro = theme.brightness == Brightness.dark;
    final fg = esOscuro ? Colors.white : theme.primaryColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: esOscuro ? theme.primaryColor.withValues(alpha: 0.45) : theme.primaryColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Negocio.getIcono(n.categoria), size: 16, color: fg),
        const SizedBox(width: 6),
        Text(Negocio.getNombreCategoria(n.categoria), style: TextStyle(fontSize: 13, color: fg, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _iconoCentro(Negocio n) => Center(child: Icon(Negocio.getIcono(n.categoria), size: 60, color: Theme.of(context).primaryColor));

  Widget _buildContacto(Negocio n) {
    final items = <Widget>[];
    if (n.telefono != null) { items.add(_PhoneRow(telefono: n.telefono!)); }
    if (n.email != null) { items.add(_ContactoRow(icono: Icons.email, texto: n.email!, labelAccion: 'Email',
        onAction: () => url_launcher.launchUrl(Uri.parse('mailto:${n.email}'), mode: url_launcher.LaunchMode.externalApplication))); }
    if (n.sitioWeb != null) {
      final uri = n.sitioWeb!.startsWith('http') ? Uri.parse(n.sitioWeb!) : Uri.parse('https://${n.sitioWeb}');
      items.add(_ContactoRow(icono: Icons.language, texto: n.sitioWeb!, labelAccion: 'Visitar',
          onAction: () => url_launcher.launchUrl(uri, mode: url_launcher.LaunchMode.externalApplication)));
    }
    if (items.isEmpty && n.whatsapp == null && n.redesSociales == null) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Contacto', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8))),
      const SizedBox(height: 8),
      ...items,
      _buildRedesSociales(n),
    ]);
  }

  Widget _buildRedesSociales(Negocio n) {
    final iconos = <Widget>[];
    if (n.whatsapp != null) { iconos.add(_SocialIcon(plataforma: 'WhatsApp', color: const Color(0xFF25D366), icono: FontAwesomeIcons.whatsapp,
        onTap: () => url_launcher.launchUrl(Uri.parse('https://wa.me/${n.whatsapp}'), mode: url_launcher.LaunchMode.externalApplication))); }
    if (n.redesSociales != null) {
      try {
        for (final e in jsonDecode(n.redesSociales!) as List) {
          final p = (e as Map<String, dynamic>)['p'] as String? ?? '';
          final v = e['v'] as String? ?? '';
          final uri = v.startsWith('http') ? Uri.parse(v) : Uri.parse('https://$v');
          iconos.add(_SocialIcon(plataforma: p, color: _colorRedSocial(p), icono: _iconoRedSocial(p),
              onTap: () => url_launcher.launchUrl(uri, mode: url_launcher.LaunchMode.externalApplication)));
        }
      } catch (_) {}
    }
    if (iconos.isEmpty) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(top: 8), child: Wrap(spacing: 16, runSpacing: 12, children: iconos));
  }

  Color _colorRedSocial(String p) {
    switch (p.toLowerCase()) {
      case 'whatsapp': return const Color(0xFF25D366);
      case 'facebook': return const Color(0xFF1877F2);
      case 'instagram': return const Color(0xFFE4405F);
      case 'twitter': case 'x': return const Color(0xFF1DA1F2);
      case 'telegram': return const Color(0xFF0088CC);
      case 'linkedin': return const Color(0xFF0A66C2);
      case 'pinterest': return const Color(0xFFBD081C);
      case 'tiktok': return const Color(0xFF000000);
      case 'youtube': return const Color(0xFFFF0000);
      default: return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    }
  }

  dynamic _iconoRedSocial(String p) {
    switch (p.toLowerCase()) {
      case 'whatsapp': return FontAwesomeIcons.whatsapp;
      case 'facebook': return FontAwesomeIcons.facebook;
      case 'instagram': return FontAwesomeIcons.instagram;
      case 'twitter': case 'x': return FontAwesomeIcons.xTwitter;
      case 'telegram': return FontAwesomeIcons.telegram;
      case 'linkedin': return FontAwesomeIcons.linkedin;
      case 'pinterest': return FontAwesomeIcons.pinterest;
      case 'tiktok': return FontAwesomeIcons.tiktok;
      case 'youtube': return FontAwesomeIcons.youtube;
      default: return Icons.share;
    }
  }

  Widget _buildHorario(Negocio n) {
    if (n.horario == null) return const SizedBox.shrink();
    final estado = _obtenerEstadoHorario(n.horario!);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Horario', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8))),
      const SizedBox(height: 8),
      Row(children: [
        Text(n.horario!, style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
        const Spacer(),
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: estado.abierto ? Colors.green : Colors.red),
        ),
        const SizedBox(width: 8),
        Text(estado.abierto ? 'Abierto' : 'Cerrado',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: estado.abierto ? Colors.green : Colors.red)),
      ]),
    ]);
  }

  static const _24hPatterns = ['24 horas', '24h', '24 hrs', 'check-in 24', 'acceso 24', 'emergencias 24'];

  ({bool abierto, String texto}) _obtenerEstadoHorario(String horario) {
    final h = horario.toLowerCase();
    if (_24hPatterns.any((p) => h.contains(p))) return (abierto: true, texto: 'Abierto 24 horas');

    final match = RegExp(r'(\d{1,2}):(\d{2})\s*[–\-–]\s*(\d{1,2}):(\d{2})').firstMatch(h);
    if (match == null) return (abierto: false, texto: horario);

    final ahora = DateTime.now();
    final apertura = int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
    final cierre = int.parse(match.group(3)!) * 60 + int.parse(match.group(4)!);
    final minActual = ahora.hour * 60 + ahora.minute;
    final abierto = minActual >= apertura && minActual < cierre;
    return (abierto: abierto, texto: horario);
  }

  Widget _buildUbicacion(Negocio n) {
    if (n.direccion == null) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Ubicación', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8))),
      const SizedBox(height: 8),
      _InfoRow(icono: Icons.location_on, texto: n.direccion!),
    ]);
  }

  Widget _buildProductos() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Productos y servicios', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8))),
        const Spacer(),
        Text('${_productos.length}', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 13)),
      ]),
      const SizedBox(height: 12),
      ..._productos.map(_buildProductoItem),
    ]);
  }

  Widget _buildProductoItem(ProductoServicio p) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 48, height: 48,
          decoration: BoxDecoration(color: Theme.of(context).primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: p.fotoLocal != null
              ? ClipRRect(borderRadius: BorderRadius.circular(10),
                  child: Image.file(File(p.fotoLocal!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.shopping_bag, size: 24, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))))
              : Icon(Icons.shopping_bag, size: 24, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.nombre, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          if (p.descripcion != null && p.descripcion!.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 2), child:             Text(p.descripcion!, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)))),
        ])),
        if (p.precio != null) Text('\$${p.precio!.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    ));
  }

  Widget _buildOpiniones(Negocio n) {
    final List<Widget> seccion = [];
    seccion.add(Row(children: [
      Text('Opiniones', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8))),
      const Spacer(),
      if (_opiniones.isNotEmpty) Text('${_opiniones.length}', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 13)),
    ]));
    seccion.add(const SizedBox(height: 12));
    if (_cargandoOpiniones) {
      seccion.add(const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))));
    } else {
      seccion.add(_buildOpinionesContenido(n));
    }
    seccion.add(const SizedBox(height: 12));
    seccion.add(SizedBox(width: double.infinity, child: OutlinedButton.icon(
      onPressed: () => _abrirOpinionModal(),
      icon: const Icon(Icons.rate_review, size: 18),
      label: const Text('Escribir opinión'),
      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
    )));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: seccion);
  }

  Widget _buildOpinionesContenido(Negocio n) {
    final conComentario = _opiniones.where((r) => r.comentario != null && r.comentario!.isNotEmpty).toList();
    if (conComentario.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Column(children: [
        Icon(Icons.rate_review_outlined, size: 40, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
        const SizedBox(height: 8),
        Text('No hay opiniones aún', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 14)),
      ])));
    }
    return Column(children: [
      ...conComentario.take(3).map(_buildOpinionBurbuja),
      if (conComentario.length > 3)
        Padding(padding: const EdgeInsets.only(top: 4), child: TextButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => OpinionesListScreen(negocioId: n.id, negocioNombre: n.nombre),
          )),
          child: Text('Ver todas (${conComentario.length})'),
        )),
    ]);
  }

  Widget _buildOpinionBurbuja(Opinion o) {
    final esAnonimo = o.anonimo;
    final nombre = esAnonimo ? 'Anónimo' : (o.nombreUsuario ?? 'Usuario');
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';
    final esMia = o.usuarioId == SesionService.usuarioId;
    final puedeGestionar = esMia || SesionService.usuario.esAdmin;
    return Padding(padding: const EdgeInsets.only(bottom: 16), child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: esAnonimo ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3) : Theme.of(context).primaryColor.withValues(alpha: 0.2),
          child: Text(inicial, style: TextStyle(
            color: esAnonimo ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6) : Theme.of(context).primaryColor,
            fontWeight: FontWeight.w600, fontSize: 14,
          )),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.only(left: 12, top: 10, right: 4, bottom: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(nombre, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF385898)))),
                    if (puedeGestionar) ...[
                      const SizedBox(width: 4),
                      Text('(tú)', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
                    ],
                  ]),
                  if (o.fecha != null) Text(_formatearFecha(o.fecha!), style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
                ])),
                if (puedeGestionar)
                  PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'editar') { _abrirOpinionModal(existente: o); }
                      if (v == 'eliminar') {
                        final ok = await showDialog<bool>(context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Eliminar opinión'),
                            content: const Text('¿Estás seguro de eliminar esta opinión?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await _opinionDao.eliminar(o.id);
                          unawaited(SyncService.sincronizar());
                          await _cargarOpiniones();
                        }
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'editar', child: Text('Editar')),
                      const PopupMenuItem(value: 'eliminar', child: Text('Eliminar', style: TextStyle(color: Colors.red))),
                    ],
                    icon: Icon(Icons.more_vert, size: 18, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                  ),
              ]),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _ComentarioTexto(comentario: o.comentario ?? ''),
              ),
            ]),
          ),
        ])),
      ],
    ));
  }

  String _formatearFecha(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return iso; }
  }
}

// ─── Widget de comentario expandible ─────────────────────────────────────────

class _ComentarioTexto extends StatefulWidget {
  final String comentario;
  const _ComentarioTexto({required this.comentario});

  @override
  State<_ComentarioTexto> createState() => _ComentarioTextoState();
}

class _ComentarioTextoState extends State<_ComentarioTexto> {
  bool _expandido = false;
  static const int _limiteChars = 200;

  @override
  Widget build(BuildContext context) {
    final texto = widget.comentario;
    final esLargo = texto.length > _limiteChars;
    final mostrar = _expandido || !esLargo ? texto : '${texto.substring(0, _limiteChars)}...';
    return GestureDetector(
      onTap: esLargo ? () => setState(() => _expandido = !_expandido) : null,
      child: Text(mostrar, style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), height: 1.35)),
    );
  }
}

// ─── Widgets privados ──────────────────────────────────────────────────────

class _PhoneRow extends StatelessWidget {
  final String telefono;
  const _PhoneRow({required this.telefono});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final esOscuro = theme.brightness == Brightness.dark;
    final accent = esOscuro ? Colors.white : theme.primaryColor;
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
      Icon(Icons.phone, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
      const SizedBox(width: 12),
      Expanded(child: Text(telefono, style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)))),
      _boton('Llamar', accent, () => url_launcher.launchUrl(Uri.parse('tel:$telefono'), mode: url_launcher.LaunchMode.externalApplication)),
      const SizedBox(width: 8),
      _boton('SMS', accent, () => url_launcher.launchUrl(Uri.parse('sms:$telefono'), mode: url_launcher.LaunchMode.externalApplication)),
    ]));
  }

  Widget _boton(String label, Color color, VoidCallback onPressed) {
    return OutlinedButton(onPressed: onPressed, style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 12), minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap, side: BorderSide(color: color),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ), child: Text(label, style: TextStyle(color: color, fontSize: 12)));
  }
}

class _ContactoRow extends StatelessWidget {
  final IconData icono; final String texto; final String labelAccion; final VoidCallback onAction;
  const _ContactoRow({required this.icono, required this.texto, required this.labelAccion, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final esOscuro = theme.brightness == Brightness.dark;
    final accent = esOscuro ? Colors.white : theme.primaryColor;
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
      Icon(icono, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
      const SizedBox(width: 12),
      Expanded(child: Text(texto, style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)))),
      OutlinedButton(onPressed: onAction, style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12), minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap, side: BorderSide(color: accent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ), child: Text(labelAccion, style: TextStyle(color: accent, fontSize: 12))),
    ]));
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _TabBarDelegate({required this.tabBar});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Theme.of(context).scaffoldBackgroundColor, child: tabBar);
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  bool shouldRebuild(_TabBarDelegate old) => false;
}

class _SocialIcon extends StatelessWidget {
  final String plataforma; final Color color; final dynamic icono; final VoidCallback onTap;
  const _SocialIcon({required this.plataforma, required this.color, required this.icono, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap, child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 44, height: 44, alignment: Alignment.center,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
        child: icono is FaIconData ? FaIcon(icono, size: 22, color: color) : Icon(icono, size: 22, color: color)),
      const SizedBox(height: 4),
      Text(plataforma, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
    ]));
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icono; final String texto;
  const _InfoRow({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
    Icon(icono, size: 20, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
    const SizedBox(width: 12),
    Expanded(child: Text(texto, style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)))),
  ]));
}

// ─── Modal de rating (solo estrellas) ──────────────────────────────────────

class _RatingModal extends StatelessWidget {
  final int calificacionActual;
  const _RatingModal({required this.calificacionActual});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('Califica este negocio', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Tu calificación ayuda a otros usuarios', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
          const SizedBox(height: 20),
          _EstrellasRating(seleccionInicial: calificacionActual, onSeleccion: (estrellas) => Navigator.pop(context, estrellas)),
          const SizedBox(height: 20),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ]),
      ),
    );
  }
}

class _EstrellasRating extends StatefulWidget {
  final int seleccionInicial;
  final ValueChanged<int> onSeleccion;
  const _EstrellasRating({required this.seleccionInicial, required this.onSeleccion});

  @override
  State<_EstrellasRating> createState() => _EstrellasRatingState();
}

class _EstrellasRatingState extends State<_EstrellasRating> {
  late int _seleccion;

  @override
  void initState() { super.initState(); _seleccion = widget.seleccionInicial; }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) {
          final llena = i < _seleccion;
          return GestureDetector(
            onTap: () => setState(() => _seleccion = i + 1),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(llena ? Icons.star : Icons.star_border, size: 48, color: Colors.amber[700]),
            ),
          );
        })),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => widget.onSeleccion(_seleccion),
            child: const Text('Confirmar'),
          ),
        ),
      ],
    );
  }
}

// ─── Modal de opinión (comentario + anónimo) ──────────────────────────────

class _OpinionModal extends StatefulWidget {
  final String negocioId;
  final Opinion? existente;
  const _OpinionModal({required this.negocioId, this.existente});

  @override
  State<_OpinionModal> createState() => _OpinionModalState();
}

class _OpinionModalState extends State<_OpinionModal> {
  late TextEditingController _comentarioCtrl;
  late bool _anonimo;

  @override
  void initState() {
    super.initState();
    _comentarioCtrl = TextEditingController(text: widget.existente?.comentario ?? '');
    _anonimo = widget.existente?.anonimo ?? false;
  }

  @override
  void dispose() { _comentarioCtrl.dispose(); super.dispose(); }

  void _guardar() {
    Navigator.pop(context, Opinion(
      id: widget.existente?.id ?? const Uuid().v4(),
      usuarioId: SesionService.usuarioId,
      negocioId: widget.existente?.negocioId ?? widget.negocioId,
      comentario: _comentarioCtrl.text.trim().isEmpty ? null : _comentarioCtrl.text.trim(),
      anonimo: _anonimo,
      fecha: DateTime.now().toIso8601String(),
      nombreUsuario: SesionService.usuario.nombre,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text(widget.existente != null ? 'Editar opinión' : 'Escribe tu opinión', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _comentarioCtrl,
            decoration: const InputDecoration(hintText: 'Cuenta tu experiencia...', border: OutlineInputBorder()),
            maxLines: 4,
            autofocus: true,
          ),
          const SizedBox(height: 16),
          Row(children: [
            const Text('Publicar como anónimo', style: TextStyle(fontSize: 14)),
            const Spacer(),
            Switch(value: _anonimo, onChanged: (v) => setState(() => _anonimo = v)),
          ]),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: FilledButton(
            onPressed: _guardar,
            child: Text(widget.existente != null ? 'Actualizar' : 'Publicar'),
          )),
        ]),
      ),
    );
  }
}
