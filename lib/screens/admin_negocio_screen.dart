import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../database/negocio_dao.dart';
import '../database/producto_servicio_dao.dart';
import '../database/calificacion_dao.dart';
import '../models/negocio.dart';
import '../models/producto_servicio.dart';
import '../services/sesion_service.dart';
import 'agregar_negocio_screen.dart';
import 'opiniones_list_screen.dart';

class AdminNegocioScreen extends StatefulWidget {
  final Negocio negocio;
  const AdminNegocioScreen({super.key, required this.negocio});

  @override
  State<AdminNegocioScreen> createState() => _AdminNegocioScreenState();
}

class _AdminNegocioScreenState extends State<AdminNegocioScreen> {
  final NegocioDao _negocioDao = NegocioDao();
  final CalificacionDao _calificacionDao = CalificacionDao();
  final ProductoServicioDao _productoDao = ProductoServicioDao();
  late Negocio _negocio;
  double _calificacionPromedio = 0;
  int _totalCalificaciones = 0;
  List<ProductoServicio> _productos = [];
  bool _cargandoProductos = true;

  @override
  void initState() {
    super.initState();
    _negocio = widget.negocio;
    _cargarEstadisticas();
    _cargarProductos();
  }

  Future<void> _cargarEstadisticas() async {
    try {
      final stats = await _calificacionDao.obtenerEstadisticas(_negocio.id);
      if (mounted) setState(() {
        _calificacionPromedio = stats['promedio'] as double;
        _totalCalificaciones = stats['total'] as int;
      });
    } catch (_) {}
  }

  Future<void> _cargarProductos() async {
    try {
      final productos = await _productoDao.obtenerPorNegocio(_negocio.id);
      if (mounted) setState(() { _productos = productos; _cargandoProductos = false; });
    } catch (_) {
      if (mounted) setState(() => _cargandoProductos = false);
    }
  }

  Future<void> _recargarNegocio() async {
    final propios = await _negocioDao.obtenerPropios(SesionService.usuarioId);
    if (!mounted) return;
    final actualizado = propios.where((n) => n.id == _negocio.id).firstOrNull;
    if (actualizado != null) {
      setState(() => _negocio = actualizado);
    } else {
      Navigator.pop(context, true);
    }
  }

  Future<void> _eliminar() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar negocio'),
        content: Text('¿Eliminar "${_negocio.nombre}" permanentemente?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _negocioDao.eliminarPropio(_negocio.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Negocio eliminado')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  double get _promedioCalificacion => _calificacionPromedio;

  Future<void> _agregarProducto({ProductoServicio? existente}) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _DialogProducto(producto: existente),
    );
    if (result == null || !mounted) return;
    final esNuevo = existente == null;
    final item = ProductoServicio(
      id: esNuevo ? const Uuid().v4() : existente.id,
      negocioId: _negocio.id,
      nombre: result['nombre'] as String,
      descripcion: result['descripcion'] as String?,
      precio: result['precio'] as double?,
      disponible: result['disponible'] as bool,
      fotoLocal: result['foto_local'] as String?,
    );
    try {
      await _productoDao.guardar(item, esNuevo: esNuevo);
      _cargarProductos();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _eliminarProducto(ProductoServicio item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar'),
        content: Text('¿Eliminar "${item.nombre}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _productoDao.eliminar(item.id);
      _cargarProductos();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final n = _negocio;
    return Scaffold(
      appBar: AppBar(
        title: Text(n.nombre, style: const TextStyle(fontSize: 16)),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'editar') {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => AgregarNegocioScreen(negocio: _negocio)));
                if (!mounted) return;
                _recargarNegocio();
              } else if (v == 'eliminar') {
                _eliminar();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'editar', child: ListTile(leading: Icon(Icons.edit), title: Text('Editar'), dense: true)),
              const PopupMenuItem(value: 'eliminar', child: ListTile(leading: Icon(Icons.delete_outline, color: Colors.red), title: Text('Eliminar', style: TextStyle(color: Colors.red)), dense: true)),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(theme, n),
            if (n.fotos.isNotEmpty) ...[const SizedBox(height: 20), _buildCover(theme, n)],
            const SizedBox(height: 24),
            _buildStats(theme),
            const SizedBox(height: 24),
            _buildDescripcion(theme, n),
            const SizedBox(height: 24),
            _buildContacto(theme, n),
            const SizedBox(height: 24),
            _buildDireccion(theme, n),
            const SizedBox(height: 24),
            _buildRedesSociales(theme, n),
            const SizedBox(height: 24),
            _buildHorario(theme, n),
            const SizedBox(height: 24),
            _buildUbicacion(theme, n),
            const SizedBox(height: 24),
            _buildProductos(theme),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, Negocio n) {
    final statusColor = n.estado == 'aprobado'
        ? Colors.green
        : n.estado == 'rechazado'
            ? Colors.red
            : Colors.orange;
    final statusLabel = n.estado == 'aprobado'
        ? 'Aprobado'
        : n.estado == 'rechazado'
            ? 'Rechazado'
            : 'Pendiente';

    return Row(
      children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: theme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Negocio.getIcono(n.categoria), size: 32, color: theme.primaryColor),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(n.nombre, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(Negocio.getNombreCategoria(n.categoria), style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCover(ThemeData theme, Negocio n) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: double.infinity,
        height: 160,
        child: Image.file(File(n.fotos.first), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()),
      ),
    );
  }

  Widget _buildStats(ThemeData theme) {
    final promedio = _promedioCalificacion;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(theme: theme, icono: Icons.analytics, titulo: 'Estadísticas'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _StatCard(theme, Icons.visibility_outlined, '-', 'Vistas')),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(theme, Icons.star_outline, promedio > 0 ? promedio.toStringAsFixed(1) : '-', 'Puntuación')),
            const SizedBox(width: 12),
              Expanded(child: _StatCard(theme, Icons.comment, _totalCalificaciones.toString(), 'Opiniones',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OpinionesListScreen(negocioId: _negocio.id, negocioNombre: _negocio.nombre))),)),
          ],
        ),
      ],
    );
  }

  Widget _buildDescripcion(ThemeData theme, Negocio n) {
    if (n.descripcion == null || n.descripcion!.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(theme: theme, icono: Icons.description, titulo: 'Descripción'),
        const SizedBox(height: 12),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(n.descripcion!, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, height: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildContacto(ThemeData theme, Negocio n) {
    final items = <_InfoItem>[];
    if (n.telefono != null && n.telefono!.isNotEmpty) items.add(_InfoItem(Icons.phone, 'Teléfono', n.telefono!));
    if (n.whatsapp != null && n.whatsapp!.isNotEmpty) items.add(_InfoItem(Icons.chat, 'WhatsApp', n.whatsapp!));
    if (n.email != null && n.email!.isNotEmpty) items.add(_InfoItem(Icons.email, 'Correo electrónico', n.email!));
    if (n.sitioWeb != null && n.sitioWeb!.isNotEmpty) items.add(_InfoItem(Icons.language, 'Sitio web', n.sitioWeb!));
    if (items.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(theme: theme, icono: Icons.contact_phone, titulo: 'Contacto'),
        const SizedBox(height: 12),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: items.map((item) => _InfoTile(theme, item.icono, item.label, item.valor)).toList()),
          ),
        ),
      ],
    );
  }

  Widget _buildDireccion(ThemeData theme, Negocio n) {
    if (n.direccion == null || n.direccion!.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(theme: theme, icono: Icons.location_on, titulo: 'Dirección'),
        const SizedBox(height: 12),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.location_on, size: 20, color: theme.primaryColor),
                const SizedBox(width: 12),
                Expanded(child: Text(n.direccion!, style: const TextStyle(fontSize: 15))),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRedesSociales(ThemeData theme, Negocio n) {
    if (n.redesSociales == null || n.redesSociales!.isEmpty) return const SizedBox();
    List<Map<String, dynamic>> redes = [];
    try {
      final parsed = jsonDecode(n.redesSociales!);
      if (parsed is List) redes = parsed.cast<Map<String, dynamic>>();
    } catch (_) {}
    if (redes.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(theme: theme, icono: Icons.share, titulo: 'Redes sociales'),
        const SizedBox(height: 12),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: redes.map((r) {
              final p = r['p'] as String? ?? '';
              final v = r['v'] as String? ?? '';
              return _InfoTile(theme, Icons.link, p, v);
            }).toList()),
          ),
        ),
      ],
    );
  }

  Widget _buildHorario(ThemeData theme, Negocio n) {
    if (n.horario == null || n.horario!.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(theme: theme, icono: Icons.access_time, titulo: 'Horario'),
        const SizedBox(height: 12),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.access_time, size: 20, color: theme.primaryColor),
                const SizedBox(width: 12),
                Expanded(child: Text(_formatearHorario(n.horario!), style: const TextStyle(fontSize: 15))),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUbicacion(ThemeData theme, Negocio n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(theme: theme, icono: Icons.map, titulo: 'Ubicación'),
        const SizedBox(height: 12),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _InfoTile(theme, Icons.map, 'Coordenadas', '${n.lat.toStringAsFixed(6)}, ${n.lon.toStringAsFixed(6)}'),
          ),
        ),
      ],
    );
  }

  Widget _buildProductos(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _SectionHeader(theme: theme, icono: Icons.inventory_2, titulo: 'Productos / Servicios'),
            TextButton.icon(
              onPressed: () => _agregarProducto(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Agregar'),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_cargandoProductos)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(strokeWidth: 2)))
        else if (_productos.isEmpty)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text('No has agregado productos o servicios', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
              ),
            ),
          )
        else
          ...List.generate(_productos.length, (i) => _buildProductoItem(theme, _productos[i])),
      ],
    );
  }

  Widget _buildProductoItem(ThemeData theme, ProductoServicio item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            if (item.fotoLocal != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 48, height: 48,
                  child: Image.file(File(item.fotoLocal!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => _productoPlaceholder(theme, item.nombre)),
                ),
              )
            else
              _productoPlaceholder(theme, item.nombre),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(item.nombre, style: const TextStyle(fontWeight: FontWeight.w600))),
                      if (!item.disponible)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: theme.colorScheme.onSurface.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                          child: Text('No disponible', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                        ),
                    ],
                  ),
                  if (item.descripcion != null && item.descripcion!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(item.descripcion!, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                  if (item.precio != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('\$${item.precio!.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: theme.primaryColor)),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'editar') _agregarProducto(existente: item);
                if (v == 'eliminar') _eliminarProducto(item);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'editar', child: Text('Editar')),
                const PopupMenuItem(value: 'eliminar', child: Text('Eliminar', style: TextStyle(color: Colors.red))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _productoPlaceholder(ThemeData theme, String nombre) {
    return Container(
      width: 48, height: 48,
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.sell, size: 24, color: theme.primaryColor),
    );
  }

  String _formatearHorario(String h) {
    if (h == '24 horas') return 'Abierto 24 horas';
    if (h.startsWith('Lun-Dom ')) {
      final t = h.substring(8);
      return 'Todos los días: ${t.replaceAll('-', ' - ')}';
    }
    final dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final partes = h.split('|');
    final sb = StringBuffer();
    for (int i = 0; i < partes.length && i < 7; i++) {
      if (sb.isNotEmpty) sb.write('\n');
      sb.write('${dias[i]}: ');
      if (partes[i] == 'Cerrado') {
        sb.write('Cerrado');
      } else {
        sb.write(partes[i].replaceAll('-', ' - '));
      }
    }
    return sb.toString();
  }

}

class _DialogProducto extends StatefulWidget {
  final ProductoServicio? producto;
  const _DialogProducto({this.producto});

  @override
  State<_DialogProducto> createState() => _DialogProductoState();
}

class _DialogProductoState extends State<_DialogProducto> {
  final _nombreCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  bool _disponible = true;
  String? _fotoPath;
  bool get _editando => widget.producto != null;

  @override
  void initState() {
    super.initState();
    final p = widget.producto;
    if (p != null) {
      _nombreCtrl.text = p.nombre;
      _descripcionCtrl.text = p.descripcion ?? '';
      _precioCtrl.text = p.precio?.toStringAsFixed(2) ?? '';
      _disponible = p.disponible;
      _fotoPath = p.fotoLocal;
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _precioCtrl.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFoto() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 512);
    if (picked != null) setState(() => _fotoPath = picked.path);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(_editando ? 'Editar producto' : 'Agregar producto'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: _seleccionarFoto,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity, height: 120,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                    image: _fotoPath != null ? DecorationImage(image: FileImage(File(_fotoPath!)), fit: BoxFit.cover) : null,
                  ),
                  child: _fotoPath == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate, size: 36, color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(height: 4),
                            Text('Foto del producto', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                          ],
                        )
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            Positioned(
                              top: 4, right: 4,
                              child: CircleAvatar(
                                backgroundColor: Colors.black54, radius: 14,
                                child: IconButton(
                                  icon: const Icon(Icons.close, size: 14, color: Colors.white),
                                  onPressed: () => setState(() => _fotoPath = null),
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descripcionCtrl,
                decoration: const InputDecoration(labelText: 'Descripción (opcional)', border: OutlineInputBorder()),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _precioCtrl,
                decoration: const InputDecoration(labelText: 'Precio (opcional)', border: OutlineInputBorder(), prefixText: '\$ '),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Disponible', style: TextStyle(fontSize: 14)),
                value: _disponible,
                onChanged: (v) => setState(() => _disponible = v ?? true),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            if (_nombreCtrl.text.trim().isEmpty) return;
            Navigator.pop(context, {
              'nombre': _nombreCtrl.text.trim(),
              'descripcion': _descripcionCtrl.text.trim().isEmpty ? null : _descripcionCtrl.text.trim(),
              'precio': double.tryParse(_precioCtrl.text.trim().replaceAll(',', '.')),
              'disponible': _disponible,
              'foto_local': _fotoPath,
            });
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final ThemeData theme;
  final IconData icono;
  final String titulo;

  const _SectionHeader({required this.theme, required this.icono, required this.titulo});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, size: 20, color: theme.primaryColor),
        const SizedBox(width: 8),
        Text(titulo, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final ThemeData theme;
  final IconData icono;
  final String valor;
  final String label;
  final VoidCallback? onTap;

  const _StatCard(this.theme, this.icono, this.valor, this.label, {this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            children: [
              Icon(icono, color: theme.primaryColor, size: 24),
              const SizedBox(height: 8),
              Text(valor, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Text(label, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoItem {
  final IconData icono;
  final String label;
  final String valor;
  const _InfoItem(this.icono, this.label, this.valor);
}

class _InfoTile extends StatelessWidget {
  final ThemeData theme;
  final IconData icono;
  final String label;
  final String valor;

  const _InfoTile(this.theme, this.icono, this.label, this.valor);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: theme.primaryColor),
          const SizedBox(width: 12),
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(child: Text(valor, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
