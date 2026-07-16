import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../database/negocio_dao.dart';
import '../models/negocio.dart';
import '../services/sync_service.dart';
import '../widgets/horario_selector.dart';
import '../widgets/mapa_offline.dart';
import 'seleccionar_ubicacion_screen.dart';

class AgregarNegocioScreen extends StatefulWidget {
  final Negocio? negocio;
  const AgregarNegocioScreen({super.key, this.negocio});

  @override
  State<AgregarNegocioScreen> createState() => _AgregarNegocioScreenState();
}

class _AgregarNegocioScreenState extends State<AgregarNegocioScreen> {
  final NegocioDao _negocioDao = NegocioDao();
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _calleCtrl = TextEditingController();
  final _entreCallesCtrl = TextEditingController();
  final _numeroCtrl = TextEditingController();
  final _repartoCtrl = TextEditingController();
  final _municipioCtrl = TextEditingController();
  final _provinciaCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _sitioWebCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  String? _categoria;
  String? _horario;
  double _lat = 23.113592;
  double _lon = -82.366592;
  String? _coverPath;
  bool _whatsappIgual = false;
  int _pasoActual = 0;
  bool _intentoAvanzar = false;
  final List<_RedSocialItem> _redes = [];
  static const _plataformas = ['Telegram', 'Facebook', 'Instagram', 'X (Twitter)', 'YouTube', 'TikTok', 'LinkedIn', 'WhatsApp', 'Otra'];
  final ImagePicker _picker = ImagePicker();

  late final List<_PasoInfo> _pasos;
  bool get _editando => widget.negocio != null;

  @override
  void initState() {
    super.initState();
    _pasos = [
      _PasoInfo('Información', Icons.info_outline, 'Datos básicos del negocio'),
      _PasoInfo('Contacto', Icons.phone, 'Teléfono, redes y web'),
      _PasoInfo('Ubicación', Icons.location_on, 'Dirección y mapa'),
      _PasoInfo('Horario', Icons.access_time, 'Horarios de atención'),
      _PasoInfo('Revisar', Icons.check_circle_outline, 'Confirma los datos'),
    ];
    _prellenarFormulario();
  }

  void _prellenarFormulario() {
    final n = widget.negocio;
    if (n == null) return;
    _nombreCtrl.text = n.nombre;
    _descripcionCtrl.text = n.descripcion ?? '';
    _telefonoCtrl.text = n.telefono ?? '';
    _emailCtrl.text = n.email ?? '';
    _sitioWebCtrl.text = n.sitioWeb ?? '';
    _categoria = n.categoria;
    _lat = n.lat;
    _lon = n.lon;
    _horario = n.horario;
    if (n.fotos.isNotEmpty) _coverPath = n.fotos.first;
    if (n.whatsapp != null && n.whatsapp!.isNotEmpty) {
      if (n.whatsapp == n.telefono && n.telefono != null && n.telefono!.isNotEmpty) {
        _whatsappIgual = true;
      } else {
        _whatsappCtrl.text = n.whatsapp!;
      }
    }
    _parsearDireccion(n.direccion ?? '');
    _parsearRedesSociales(n.redesSociales ?? '');
  }

  void _parsearDireccion(String direccion) {
    if (direccion.isEmpty) return;
    final parts = direccion.split(', ').map((s) => s.trim()).toList();
    if (parts.isEmpty) return;
    _calleCtrl.text = parts[0];
    String? entre, numero;
    final rest = <String>[];
    for (int i = 1; i < parts.length; i++) {
      final p = parts[i];
      if (p.startsWith('No. ')) {
        numero = p.substring(4);
      } else if (p.startsWith('entre ')) {
        entre = p.substring(6);
      } else {
        rest.add(p);
      }
    }
    if (entre != null) _entreCallesCtrl.text = entre;
    if (numero != null) _numeroCtrl.text = numero;
    if (rest.isNotEmpty) _repartoCtrl.text = rest.isNotEmpty ? rest[0] : '';
    if (rest.length > 1) _municipioCtrl.text = rest[1];
    if (rest.length > 2) _provinciaCtrl.text = rest[2];
  }

  void _parsearRedesSociales(String json) {
    if (json.isEmpty) return;
    try {
      final parsed = jsonDecode(json);
      if (parsed is! List) return;
      for (final item in parsed) {
        final p = item['p'] as String?;
        final v = item['v'] as String? ?? '';
        final ctrl = TextEditingController(text: v);
        _redes.add(_RedSocialItem(p, ctrl));
      }
    } catch (_) {}
  }

  String get _direccionCompleta {
    final parts = [
      _calleCtrl.text.trim(),
      if (_entreCallesCtrl.text.trim().isNotEmpty) 'entre ${_entreCallesCtrl.text.trim()}',
      if (_numeroCtrl.text.trim().isNotEmpty) 'No. ${_numeroCtrl.text.trim()}',
      _repartoCtrl.text.trim(),
      _municipioCtrl.text.trim(),
      _provinciaCtrl.text.trim(),
    ].where((s) => s.isNotEmpty);
    return parts.join(', ');
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _calleCtrl.dispose();
    _entreCallesCtrl.dispose();
    _numeroCtrl.dispose();
    _repartoCtrl.dispose();
    _municipioCtrl.dispose();
    _provinciaCtrl.dispose();
    _telefonoCtrl.dispose();
    _emailCtrl.dispose();
    _sitioWebCtrl.dispose();
    _whatsappCtrl.dispose();
    for (final r in _redes) { r.ctrl.dispose(); }
    super.dispose();
  }

  bool _pasoValido() {
    switch (_pasoActual) {
      case 0: return _formKey.currentState?.validate() ?? false;
      case 1: return _formKey.currentState?.validate() ?? false;
      case 2: return _formKey.currentState?.validate() ?? false;
      case 3: return _horario != null && _horario!.isNotEmpty;
      case 4: return true;
      default: return false;
    }
  }

  void _siguiente() {
    _intentoAvanzar = true;
    if (!_pasoValido()) return;
    if (_pasoActual < 4) {
      setState(() {
        _pasoActual++;
        _intentoAvanzar = false;
      });
    }
  }

  void _anterior() {
    if (_pasoActual > 0) setState(() => _pasoActual--);
  }

  Future<void> _seleccionarUbicacion() async {
    final result = await Navigator.push<Coordenada>(
      context,
      MaterialPageRoute(
        builder: (_) => SeleccionarUbicacionScreen(latInicial: _lat, lonInicial: _lon),
      ),
    );
    if (result != null) {
      setState(() { _lat = result.latitude; _lon = result.longitude; });
    }
  }

  String get _whatsappValue {
    if (_whatsappIgual) return _telefonoCtrl.text.trim();
    return _whatsappCtrl.text.trim();
  }

  String get _redesSocialesJson {
    final lista = _redes.where((r) => r.plataforma != null && r.ctrl.text.trim().isNotEmpty).map((r) => {
      'p': r.plataforma,
      'v': r.ctrl.text.trim(),
    }).toList();
    return lista.isEmpty ? '' : jsonEncode(lista);
  }

  Future<void> _guardarNegocio() async {
    if (_nombreCtrl.text.trim().isEmpty || _categoria == null || _calleCtrl.text.trim().isEmpty || _horario == null || _horario!.isEmpty) return;

    final fotos = <String>[];
    if (_coverPath != null) fotos.add(_coverPath!);

    final esNuevo = !_editando;
    final negocio = Negocio(
      id: _editando ? widget.negocio!.id : const Uuid().v4(),
      nombre: _nombreCtrl.text.trim(),
      categoria: _categoria!,
      descripcion: _descripcionCtrl.text.trim(),
      direccion: _direccionCompleta,
      telefono: _telefonoCtrl.text.trim(),
      whatsapp: _whatsappValue,
      email: _emailCtrl.text.trim(),
      sitioWeb: _sitioWebCtrl.text.trim(),
      redesSociales: _redesSocialesJson,
      horario: _horario,
      lat: _lat,
      lon: _lon,
      origen: 'propio',
      fotos: fotos,
    );

    try {
      await _negocioDao.guardarPropio(negocio, esNuevo: esNuevo);
      unawaited(SyncService.sincronizar());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_editando ? 'Negocio actualizado correctamente' : 'Negocio guardado correctamente'),
          backgroundColor: const Color(0xFF388E3C),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $e')),
      );
    }
  }

  void _agregarRedSocial() {
    setState(() {
      _redes.add(_RedSocialItem(null, TextEditingController()));
    });
  }

  void _eliminarRedSocial(int index) {
    setState(() {
      _redes[index].ctrl.dispose();
      _redes.removeAt(index);
    });
  }

  Future<void> _seleccionarImagen() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1024);
    if (picked != null) {
      setState(() => _coverPath = picked.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar negocio' : 'Agregar negocio'),
      ),
      body: Column(
        children: [
          _buildStepperHeader(theme),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 80),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: _buildPasoActual(),
              ),
            ),
          ),
          _buildBottomBar(theme),
        ],
      ),
    );
  }

  Widget _buildStepperHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: List.generate(_pasos.length, (i) {
          final activo = i == _pasoActual;
          final completado = i < _pasoActual;
          return Expanded(
            child: GestureDetector(
              onTap: completado ? () => setState(() => _pasoActual = i) : null,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        if (i > 0) Expanded(child: Divider(thickness: 2, color: activo || completado ? theme.colorScheme.primary : theme.dividerColor)),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: completado ? theme.colorScheme.primary : (activo ? theme.colorScheme.primaryContainer : Colors.transparent),
                            border: Border.all(color: activo || completado ? theme.colorScheme.primary : theme.colorScheme.outline, width: 2),
                          ),
                          child: Center(
                            child: completado
                                ? Icon(Icons.check, size: 18, color: theme.colorScheme.onPrimary)
                                : Icon(_pasos[i].icono, size: 16, color: activo ? theme.colorScheme.primary : theme.colorScheme.outline),
                          ),
                        ),
                        if (i < _pasos.length - 1) Expanded(child: Divider(thickness: 2, color: completado ? theme.colorScheme.primary : theme.dividerColor)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(_pasos[i].titulo, style: TextStyle(fontSize: 11, fontWeight: activo ? FontWeight.w600 : FontWeight.normal, color: activo ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPasoActual() {
    switch (_pasoActual) {
      case 0: return _buildPasoInfo();
      case 1: return _buildPasoContacto();
      case 2: return _buildPasoUbicacion();
      case 3: return _buildPasoHorario();
      case 4: return _buildPasoRevisar();
      default: return const SizedBox();
    }
  }

  Widget _buildPasoInfo() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Datos básicos', style: theme.textTheme.titleLarge),
        const SizedBox(height: 24),
        // Foto de portada
        Center(
          child: InkWell(
            onTap: _seleccionarImagen,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              height: 180,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
                image: _coverPath != null
                    ? DecorationImage(
                        image: FileImage(File(_coverPath!)),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _coverPath == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate, size: 48, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(height: 8),
                        Text('Foto de portada', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14)),
                        Text('Toca para seleccionar', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                      ],
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Positioned(
                          top: 8, right: 8,
                          child: CircleAvatar(
                            backgroundColor: Colors.black54,
                            radius: 16,
                            child: IconButton(
                              icon: const Icon(Icons.close, size: 16, color: Colors.white),
                              onPressed: () => setState(() => _coverPath = null),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        TextFormField(
          controller: _nombreCtrl,
          decoration: const InputDecoration(
            labelText: 'Nombre del negocio *',
            prefixIcon: Icon(Icons.store),
            hintText: 'Ej: Cafetería La Esquina',
          ),
          onChanged: (_) => setState(() {}),
          validator: (v) => v == null || v.trim().isEmpty ? 'El nombre es obligatorio' : null,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            labelText: 'Categoría *',
            prefixIcon: Icon(Icons.category),
          ),
          initialValue: _categoria,
          items: Negocio.categorias.map((cat) {
            return DropdownMenuItem(
              value: cat,
              child: Row(
                children: [
                  Icon(Negocio.getIcono(cat), size: 20, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Text(Negocio.getNombreCategoria(cat)),
                ],
              ),
            );
          }).toList(),
          onChanged: (v) => setState(() => _categoria = v),
          validator: (v) => v == null ? 'Selecciona una categoría' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descripcionCtrl,
          decoration: const InputDecoration(
            labelText: 'Descripción',
            prefixIcon: Icon(Icons.description),
            hintText: 'Breve descripción del negocio...',
          ),
          maxLines: 4,
        ),
      ],
    );
  }

  Widget _buildPasoContacto() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Contacto', style: theme.textTheme.titleLarge),
        const SizedBox(height: 24),
        TextFormField(
          controller: _telefonoCtrl,
          decoration: const InputDecoration(
            labelText: 'Teléfono',
            prefixIcon: Icon(Icons.phone),
            hintText: '+53 5 1234567',
          ),
          keyboardType: TextInputType.phone,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return null;
            if (!RegExp(r'^[\d\s\+\-\(\)]{7,}$').hasMatch(v.trim())) return 'Formato inválido';
            return null;
          },
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: const Text('WhatsApp usa el mismo número', style: TextStyle(fontSize: 14)),
          value: _whatsappIgual,
          onChanged: (v) => setState(() => _whatsappIgual = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
        ),
        if (!_whatsappIgual)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TextFormField(
              controller: _whatsappCtrl,
              decoration: const InputDecoration(
                labelText: 'WhatsApp (si es diferente)',
                prefixIcon: Icon(Icons.chat),
              ),
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                if (!RegExp(r'^[\d\s\+\-\(\)]{7,}$').hasMatch(v.trim())) return 'Formato inválido';
                return null;
              },
            ),
          ),
        TextFormField(
          controller: _emailCtrl,
          decoration: const InputDecoration(
            labelText: 'Correo electrónico',
            prefixIcon: Icon(Icons.email),
            hintText: 'correo@ejemplo.com',
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return null;
            if (!RegExp(r'^[\w\-\.]+@[\w\-\.]+\.\w{2,}$').hasMatch(v.trim())) return 'Correo inválido';
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _sitioWebCtrl,
          decoration: const InputDecoration(
            labelText: 'Sitio web',
            prefixIcon: Icon(Icons.language),
            hintText: 'https://ejemplo.com',
          ),
          keyboardType: TextInputType.url,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return null;
            if (!RegExp(r'^https?://').hasMatch(v.trim())) return 'Debe comenzar con http:// o https://';
            return null;
          },
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Redes sociales', style: theme.textTheme.labelLarge),
            TextButton.icon(
              onPressed: _agregarRedSocial,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Agregar'),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
          ],
        ),
        if (_redes.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('No has agregado redes sociales', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
          )
        else
          ...List.generate(_redes.length, (i) => _buildRedSocialItem(i, theme)),
      ],
    );
  }

  Widget _buildRedSocialItem(int index, ThemeData theme) {
    final item = _redes[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              initialValue: item.plataforma,
              decoration: const InputDecoration(
                labelText: 'Plataforma',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: _plataformas.map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) => setState(() => _redes[index] = _RedSocialItem(v, item.ctrl)),
              isExpanded: true,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: TextField(
              controller: item.ctrl,
              decoration: const InputDecoration(
                labelText: 'Usuario / URL',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          IconButton(
            onPressed: () => _eliminarRedSocial(index),
            icon: Icon(Icons.remove_circle_outline, color: theme.colorScheme.error, size: 20),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            tooltip: 'Eliminar',
          ),
        ],
      ),
    );
  }

  Widget _buildPasoUbicacion() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ubicación', style: theme.textTheme.titleLarge),
        const SizedBox(height: 24),
        TextFormField(
          controller: _calleCtrl,
          decoration: const InputDecoration(
            labelText: 'Calle *',
            prefixIcon: Icon(Icons.signpost),
            hintText: 'Nombre de la calle',
          ),
          keyboardType: TextInputType.text,
          validator: (v) => v == null || v.trim().isEmpty ? 'La calle es obligatoria' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _entreCallesCtrl,
          decoration: const InputDecoration(
            labelText: 'Entre calles',
            hintText: 'Calle 1 y Calle 2',
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _numeroCtrl,
                decoration: const InputDecoration(
                  labelText: 'Número',
                  hintText: 'Ej: 123, Edificio 3 Apt 5',
                ),
                keyboardType: TextInputType.text,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _repartoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reparto / C. Popular',
                  hintText: 'Ej: Vedado',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _municipioCtrl,
                decoration: const InputDecoration(
                  labelText: 'Municipio',
                  hintText: 'Ej: Plaza',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _provinciaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Provincia',
                  hintText: 'Ej: La Habana',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Ubicación en el mapa', style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        InkWell(
          onTap: _seleccionarUbicacion,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(12),
              color: theme.colorScheme.surfaceContainerLow,
            ),
            child: Row(
              children: [
                Icon(Icons.map, color: theme.colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Toca para abrir el mapa', style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.primary)),
                      const SizedBox(height: 2),
                      Text('${_lat.toStringAsFixed(4)}, ${_lon.toStringAsFixed(4)}', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasoHorario() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Horario', style: theme.textTheme.titleLarge),
        const SizedBox(height: 24),
        HorarioSelector(
          horarioInicial: _horario,
          onChanged: (v) => setState(() { _horario = v; }),
        ),
        if (_intentoAvanzar && (_horario == null || _horario!.isEmpty))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Selecciona un horario antes de continuar',
              style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildPasoRevisar() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Revisa antes de guardar', style: theme.textTheme.titleLarge),
        const SizedBox(height: 24),
        _buildResumenCard(theme, Icons.store, 'Nombre', _nombreCtrl.text.trim() == '' ? '(sin nombre)' : _nombreCtrl.text.trim()),
        const Divider(height: 1),
        _buildResumenCard(theme, Icons.category, 'Categoría', _categoria == null ? '(sin seleccionar)' : Negocio.getNombreCategoria(_categoria!)),
        if (_descripcionCtrl.text.trim().isNotEmpty) ...[const Divider(height: 1), _buildResumenCard(theme, Icons.description, 'Descripción', _descripcionCtrl.text.trim())],
        if (_telefonoCtrl.text.trim().isNotEmpty) ...[const Divider(height: 1), _buildResumenCard(theme, Icons.phone, 'Teléfono', _telefonoCtrl.text.trim())],
        if (_emailCtrl.text.trim().isNotEmpty) ...[const Divider(height: 1), _buildResumenCard(theme, Icons.email, 'Email', _emailCtrl.text.trim())],
        if (_sitioWebCtrl.text.trim().isNotEmpty) ...[const Divider(height: 1), _buildResumenCard(theme, Icons.language, 'Sitio web', _sitioWebCtrl.text.trim())],
        if (_redes.isNotEmpty) ...[const Divider(height: 1), _buildResumenCard(theme, Icons.share, 'Redes sociales', _redes.where((r) => r.plataforma != null && r.ctrl.text.trim().isNotEmpty).map((r) => '${r.plataforma}: ${r.ctrl.text.trim()}').join(', '))],
        if (_coverPath != null) ...[const Divider(height: 1), _buildResumenCard(theme, Icons.image, 'Portada', '1 foto seleccionada')],
        if (_direccionCompleta.isNotEmpty) ...[const Divider(height: 1), _buildResumenCard(theme, Icons.location_on, 'Dirección', _direccionCompleta)],
        const Divider(height: 1),
        _buildResumenCard(theme, Icons.map, 'Coordenadas', '${_lat.toStringAsFixed(4)}, ${_lon.toStringAsFixed(4)}'),
        if (_horario != null && _horario!.isNotEmpty) ...[const Divider(height: 1), _buildResumenCard(theme, Icons.access_time, 'Horario', _formatearHorario(_horario))],
      ],
    );
  }

  Widget _buildResumenCard(ThemeData theme, IconData icono, String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(label, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(valor, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  String _formatearHorario(String? h) {
    if (h == null || h.isEmpty) return '';
    if (h == '24 horas') return 'Abierto 24 horas';
    if (h.startsWith('Lun-Dom ')) {
      final t = h.substring(8);
      return 'Todos los días: ${t.replaceAll('-', ' - ')}';
    }
    final dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final partes = h.split('|');
    final sb = StringBuffer();
    for (int i = 0; i < partes.length && i < 7; i++) {
      if (sb.isNotEmpty) sb.write(', ');
      sb.write('${dias[i]} ');
      if (partes[i] == 'Cerrado') {
        sb.write('Cerrado');
      } else {
        sb.write(partes[i].replaceAll('-', ' - '));
      }
    }
    return sb.toString();
  }

  Widget _buildBottomBar(ThemeData theme) {
    final esUltimo = _pasoActual == _pasos.length - 1;
    final ancho = MediaQuery.of(context).size.width;
    final esAngosto = ancho < 360;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: esAngosto ? 8 : 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_pasoActual > 0)
              Expanded(
                child: esUltimo
                    ? OutlinedButton.icon(
                        onPressed: _anterior,
                        icon: const Icon(Icons.arrow_back, size: 18),
                        label: FittedBox(child: Text('Anterior', style: TextStyle(fontSize: esAngosto ? 12 : 14))),
                      )
                    : OutlinedButton(
                        onPressed: _anterior,
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: esAngosto ? 8 : 14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_back, size: 18),
                            const SizedBox(width: 4),
                            FittedBox(child: Text('Anterior', style: TextStyle(fontSize: esAngosto ? 12 : 14))),
                          ],
                        ),
                      ),
              ),
            if (_pasoActual > 0) SizedBox(width: esAngosto ? 8 : 12),
            Expanded(
              child: esUltimo
                  ? FilledButton.icon(
                      onPressed: _guardarNegocio,
                      icon: const Icon(Icons.save, size: 18),
                      label: FittedBox(child: Text('Guardar', style: TextStyle(fontSize: esAngosto ? 12 : 14))),
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: esAngosto ? 8 : 14),
                      ),
                    )
                  : FilledButton(
                      onPressed: _siguiente,
                      style: FilledButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: esAngosto ? 8 : 14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(child: Text('Siguiente', style: TextStyle(fontSize: esAngosto ? 12 : 14))),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward, size: 18),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasoInfo {
  final String titulo;
  final IconData icono;
  final String descripcion;
  const _PasoInfo(this.titulo, this.icono, this.descripcion);
}

class _RedSocialItem {
  String? plataforma;
  final TextEditingController ctrl;
  _RedSocialItem(this.plataforma, this.ctrl);
}