import 'dart:async';
import 'package:flutter/material.dart';
import '../models/negocio.dart';
import '../services/negocio_service.dart';
import '../services/radio_busqueda_service.dart';
import 'detalle_negocio_screen.dart';

class BuscarScreen extends StatefulWidget {
  final double lat;
  final double lon;

  const BuscarScreen({super.key, required this.lat, required this.lon});

  @override
  State<BuscarScreen> createState() => _BuscarScreenState();
}

class _BuscarScreenState extends State<BuscarScreen> {
  final _textoCtr = TextEditingController();
  List<Negocio> _resultados = [];
  bool _cargando = false;

  String? _categoriaFiltro;
  double _radioKm = RadioBusquedaService.radioKm.value;
  double? _calificacionMinima;
  String? _metodoPago;

  static const _metodosPago = ['Efectivo', 'Transferencia', 'Todas'];

  @override
  void dispose() {
    _textoCtr.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    setState(() => _cargando = true);
    try {
      final resultados = await NegocioService.consultarCercaDe(
        lat: widget.lat,
        lon: widget.lon,
        radioKm: _radioKm,
        texto: _textoCtr.text.trim().isEmpty ? null : _textoCtr.text.trim(),
        categoria: _categoriaFiltro,
        calificacionMinima: _calificacionMinima,
        metodoPago: _metodoPago == 'Todas' ? null : _metodoPago,
      );
      if (mounted) setState(() {
        _resultados = resultados;
        _cargando = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _mostrarFiltroCategoria() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final cats = Negocio.categorias;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Categoría', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: [
                ChoiceChip(label: const Text('Todas'), selected: _categoriaFiltro == null, onSelected: (_) {
                  setState(() => _categoriaFiltro = null);
                  Navigator.pop(ctx);
                }),
                ...cats.map((cat) => ChoiceChip(
                  label: Text(Negocio.getNombreCategoria(cat)),
                  selected: _categoriaFiltro == cat,
                  onSelected: (_) {
                    setState(() => _categoriaFiltro = cat);
                    Navigator.pop(ctx);
                  },
                )),
              ]),
              const SizedBox(height: 20),
            ]),
          ),
        );
      },
    );
  }

  void _mostrarFiltroRadio() {
    double temp = _radioKm;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Radio de búsqueda', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text('${temp.toStringAsFixed(0)} km'),
              Slider(value: temp, min: 1, max: 50, divisions: 49,
                label: '${temp.toStringAsFixed(0)} km',
                onChanged: (v) => setState(() => temp = v),
              ),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: () {
                  this.setState(() => _radioKm = temp);
                  Navigator.pop(ctx);
                },
                child: const Text('Aplicar'),
              )),
            ]),
          ),
        );
      });
      },
    );
  }

  void _mostrarFiltroCalificacion() {
    double temp = _calificacionMinima ?? 0;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Calificación mínima', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) {
                final estrellas = i + 1;
                return IconButton(
                  icon: Icon(estrellas <= temp ? Icons.star : Icons.star_border, color: Colors.amber, size: 36),
                  onPressed: () => setState(() => temp = estrellas.toDouble()),
                );
              })),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: () {
                  this.setState(() => _calificacionMinima = temp > 0 ? temp : null);
                  Navigator.pop(ctx);
                },
                child: Text(temp > 0 ? '${temp.toStringAsFixed(0)} estrellas' : 'Sin filtro'),
              )),
            ]),
          ),
        );
      });
    },
  );
}

  void _mostrarFiltroPago() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Método de pago', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ..._metodosPago.map((mp) => ListTile(
              title: Text(mp),
              leading: Icon(_metodoPago == mp ? Icons.radio_button_checked : Icons.radio_button_unchecked),
              onTap: () {
                setState(() => _metodoPago = mp == 'Todas' ? null : mp);
                Navigator.pop(ctx);
              },
            )),
            ]),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _textoCtr,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Buscar negocios...', border: InputBorder.none),
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _buscar(),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: _buscar),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(bottom: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.12))),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _FiltroChip(
                  icon: Icons.category,
                  label: _categoriaFiltro != null ? Negocio.getNombreCategoria(_categoriaFiltro!) : 'Categoría',
                  activo: _categoriaFiltro != null,
                  onTap: _mostrarFiltroCategoria,
                ),
                const SizedBox(width: 8),
                _FiltroChip(
                  icon: Icons.map,
                  label: '${_radioKm.toStringAsFixed(0)} km',
                  activo: _radioKm < 50,
                  onTap: _mostrarFiltroRadio,
                ),
                const SizedBox(width: 8),
                _FiltroChip(
                  icon: Icons.star,
                  label: _calificacionMinima != null ? '${_calificacionMinima!.toStringAsFixed(0)}+' : 'Rating',
                  activo: _calificacionMinima != null,
                  onTap: _mostrarFiltroCalificacion,
                ),
                const SizedBox(width: 8),
                _FiltroChip(
                  icon: Icons.payment,
                  label: _metodoPago ?? 'Pago',
                  activo: _metodoPago != null,
                  onTap: _mostrarFiltroPago,
                ),
              ]),
            ),
          ),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _resultados.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off, size: 60, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
                            const SizedBox(height: 16),
                            Text('Sin resultados', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 16)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _resultados.length,
                        itemBuilder: (context, index) {
                          final n = _resultados[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                              child: Icon(Negocio.getIcono(n.categoria), color: theme.primaryColor),
                            ),
                            title: Text(n.nombre),
                            subtitle: Row(children: [
                              Text(Negocio.getNombreCategoria(n.categoria)),
                              if (n.calificacion != null) ...[
                                const SizedBox(width: 8),
                                Icon(Icons.star, size: 12, color: Colors.amber),
                                Text(n.calificacion!.toStringAsFixed(1), style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 12)),
                              ],
                            ]),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetalleNegocioScreen(negocio: n))),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _FiltroChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool activo;
  final VoidCallback onTap;

  const _FiltroChip({required this.icon, required this.label, required this.activo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = activo ? theme.colorScheme.primary : theme.colorScheme.onSurface;
    return ActionChip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(fontSize: 12, color: color)),
      onPressed: onTap,
      backgroundColor: activo ? theme.colorScheme.primary.withValues(alpha: 0.15) : theme.colorScheme.onSurface.withValues(alpha: 0.08),
      side: activo ? BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.4)) : BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.15)),
    );
  }
}
