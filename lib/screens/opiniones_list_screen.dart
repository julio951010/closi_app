import 'dart:async';
import 'package:flutter/material.dart';
import '../database/opinion_dao.dart';
import '../models/opinion.dart';
import '../services/sesion_service.dart';
import '../services/sync_service.dart';

class OpinionesListScreen extends StatefulWidget {
  final String negocioId;
  final String negocioNombre;
  const OpinionesListScreen({super.key, required this.negocioId, required this.negocioNombre});

  @override
  State<OpinionesListScreen> createState() => _OpinionesListScreenState();
}

class _OpinionesListScreenState extends State<OpinionesListScreen> {
  final OpinionDao _opinionDao = OpinionDao();
  List<Opinion> _opiniones = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final opiniones = await _opinionDao.obtenerPorNegocio(widget.negocioId);
      if (mounted) setState(() { _opiniones = opiniones; _cargando = false; });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  String _formatearFecha(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return iso; }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Opiniones de ${widget.negocioNombre}', style: const TextStyle(fontSize: 16))),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _opiniones.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.rate_review_outlined, size: 64, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                      const SizedBox(height: 16),
                      Text('No hay opiniones aún', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                    itemCount: _opiniones.length,
                    itemBuilder: (context, index) {
                      final o = _opiniones[index];
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
                            backgroundColor: esAnonimo ? theme.colorScheme.onSurface.withValues(alpha: 0.3) : theme.primaryColor.withValues(alpha: 0.2),
                            child: Text(inicial, style: TextStyle(
                              color: esAnonimo ? theme.colorScheme.onSurface.withValues(alpha: 0.6) : theme.primaryColor,
                              fontWeight: FontWeight.w600, fontSize: 14,
                            )),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Container(
                              padding: const EdgeInsets.only(left: 12, top: 10, right: 4, bottom: 12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Row(children: [
                                      Flexible(child: Text(nombre, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF385898)))),
                                      if (puedeGestionar) ...[
                                        const SizedBox(width: 4),
                                        Text('(tú)', style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                                      ],
                                    ]),
                                    if (o.fecha != null) Text(_formatearFecha(o.fecha!), style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurface.withValues(alpha: 0.4))),
                                  ])),
                                  if (puedeGestionar)
                                    PopupMenuButton<String>(
                                      onSelected: (v) async {
                                        if (v == 'editar') {
                                          final result = await showModalBottomSheet<Opinion>(
                                            context: context,
                                            isScrollControlled: true,
                                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                                            builder: (_) => _OpinionEditModal(existente: o),
                                          );
                                          if (result != null) {
                                            await _opinionDao.insertar(result);
                                            unawaited(SyncService.sincronizar());
                                            await _cargar();
                                          }
                                        }
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
                                            await _cargar();
                                          }
                                        }
                                      },
                                      itemBuilder: (_) => [
                                        const PopupMenuItem(value: 'editar', child: Text('Editar')),
                                        const PopupMenuItem(value: 'eliminar', child: Text('Eliminar', style: TextStyle(color: Colors.red))),
                                      ],
                                      icon: Icon(Icons.more_vert, size: 18, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                                    ),
                                ]),
                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Text(o.comentario ?? '', style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.7), height: 1.35)),
                                ),
                              ]),
                            ),
                          ])),
                        ],
                      ));
                    },
                  ),
                ),
    );
  }
}

class _OpinionEditModal extends StatefulWidget {
  final Opinion existente;
  const _OpinionEditModal({required this.existente});

  @override
  State<_OpinionEditModal> createState() => _OpinionEditModalState();
}

class _OpinionEditModalState extends State<_OpinionEditModal> {
  late TextEditingController _comentarioCtrl;
  late bool _anonimo;

  @override
  void initState() {
    super.initState();
    _comentarioCtrl = TextEditingController(text: widget.existente.comentario ?? '');
    _anonimo = widget.existente.anonimo;
  }

  @override
  void dispose() { _comentarioCtrl.dispose(); super.dispose(); }

  void _guardar() {
    Navigator.pop(context, widget.existente.copyWith(
      comentario: _comentarioCtrl.text.trim().isEmpty ? null : _comentarioCtrl.text.trim(),
      anonimo: _anonimo,
      fecha: DateTime.now().toIso8601String(),
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
        const Text('Editar opinión', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
          child: const Text('Actualizar'),
        )),
        ]),
      ),
    );
  }
}
