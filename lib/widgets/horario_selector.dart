import 'package:flutter/material.dart';

class HorarioSelector extends StatefulWidget {
  final String? horarioInicial;
  final ValueChanged<String> onChanged;

  const HorarioSelector({
    super.key,
    this.horarioInicial,
    required this.onChanged,
  });

  @override
  State<HorarioSelector> createState() => _HorarioSelectorState();
}

enum _ModoHorario { siempreAbierto, mismoHorario, porDia }

class _HorarioSelectorState extends State<HorarioSelector> {
  static const _dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

  _ModoHorario _modo = _ModoHorario.mismoHorario;
  TimeOfDay _aperturaGlobal = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _cierreGlobal = const TimeOfDay(hour: 18, minute: 0);
  late List<_DiaConfig> _diasConfig;

  @override
  void initState() {
    super.initState();
    _diasConfig = List.generate(7, (i) => _DiaConfig(
      abierto: true,
      apertura: const TimeOfDay(hour: 9, minute: 0),
      cierre: const TimeOfDay(hour: 18, minute: 0),
    ));

    if (widget.horarioInicial != null && widget.horarioInicial!.isNotEmpty) {
      final h = widget.horarioInicial!;
      if (h == '24 horas') {
        _modo = _ModoHorario.siempreAbierto;
      } else if (h.startsWith('Lun-Dom ')) {
        _modo = _ModoHorario.mismoHorario;
        final times = h.substring(8).split('-');
        if (times.length == 2) {
          final a = _parseTime(times[0].trim());
          final c = _parseTime(times[1].trim());
          if (a != null) _aperturaGlobal = a;
          if (c != null) _cierreGlobal = c;
        }
      } else {
        _modo = _ModoHorario.porDia;
        final partes = h.split('|');
        for (int i = 0; i < partes.length && i < 7; i++) {
          final p = partes[i].trim();
          if (p == 'Cerrado') {
            _diasConfig[i] = _DiaConfig(
              abierto: false,
              apertura: _diasConfig[i].apertura,
              cierre: _diasConfig[i].cierre,
            );
          } else {
            final times = p.split('-');
            if (times.length == 2) {
              final a = _parseTime(times[0].trim());
              final c = _parseTime(times[1].trim());
              if (a != null && c != null) {
                _diasConfig[i] = _DiaConfig(abierto: true, apertura: a, cierre: c);
              }
            }
          }
        }
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _emitir(); });
  }

  TimeOfDay? _parseTime(String t) {
    final parts = t.split(':');
    if (parts.length == 2) {
      final h = int.tryParse(parts[0].trim());
      final m = int.tryParse(parts[1].trim());
      if (h != null && m != null) return TimeOfDay(hour: h, minute: m);
    }
    return null;
  }

  String _timeStr(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  void _emitir() {
    switch (_modo) {
      case _ModoHorario.siempreAbierto:
        widget.onChanged('24 horas');
        break;
      case _ModoHorario.mismoHorario:
        widget.onChanged('Lun-Dom ${_timeStr(_aperturaGlobal)}-${_timeStr(_cierreGlobal)}');
        break;
      case _ModoHorario.porDia:
        final sb = StringBuffer();
        for (int i = 0; i < 7; i++) {
          if (i > 0) sb.write('|');
          final d = _diasConfig[i];
          if (d.abierto) {
            sb.write('${_timeStr(d.apertura)}-${_timeStr(d.cierre)}');
          } else {
            sb.write('Cerrado');
          }
        }
        widget.onChanged(sb.toString());
        break;
    }
  }

  Future<void> _pickTime(TimeOfDay current, ValueChanged<TimeOfDay> onPicked) async {
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked != null) {
      onPicked(picked);
      _emitir();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<_ModoHorario>(
          segments: const [
            ButtonSegment(value: _ModoHorario.siempreAbierto, label: Text('24h'), icon: Icon(Icons.schedule, size: 16)),
            ButtonSegment(value: _ModoHorario.mismoHorario, label: Text('Todos los días'), icon: Icon(Icons.calendar_view_week, size: 16)),
            ButtonSegment(value: _ModoHorario.porDia, label: Text('Por día'), icon: Icon(Icons.list_alt, size: 16)),
          ],
          selected: {_modo},
          onSelectionChanged: (s) => setState(() { _modo = s.first; _emitir(); }),
          showSelectedIcon: false,
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(height: 20),
        if (_modo == _ModoHorario.siempreAbierto)
          _buildInfoCard(theme, Icons.check_circle, 'Abierto 24 horas, todos los días'),
        if (_modo == _ModoHorario.mismoHorario)
          _buildMismoHorario(theme),
        if (_modo == _ModoHorario.porDia)
          _buildPorDia(theme),
      ],
    );
  }

  Widget _buildInfoCard(ThemeData theme, IconData icono, String texto) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icono, color: theme.colorScheme.primary, size: 22),
          const SizedBox(width: 12),
          Text(texto, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: theme.colorScheme.primary)),
        ],
      ),
    );
  }

  Widget _buildMismoHorario(ThemeData theme) {
    return Row(
      children: [
        Expanded(child: _buildTimeButton(theme, 'Apertura', _aperturaGlobal, (t) => setState(() => _aperturaGlobal = t))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Icon(Icons.arrow_forward, size: 20, color: theme.colorScheme.onSurfaceVariant),
        ),
        Expanded(child: _buildTimeButton(theme, 'Cierre', _cierreGlobal, (t) => setState(() => _cierreGlobal = t))),
      ],
    );
  }

  Widget _buildPorDia(ThemeData theme) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 7,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final d = _diasConfig[i];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                child: Text(_dias[i], style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: d.abierto ? null : theme.colorScheme.onSurfaceVariant)),
              ),
              Switch(
                value: d.abierto,
                onChanged: (v) => setState(() { _diasConfig[i] = d.copyWith(abierto: v); _emitir(); }),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(width: 4),
              if (d.abierto) ...[
                Expanded(
                  child: InkWell(
                    onTap: () => _pickTime(d.apertura, (t) => setState(() { _diasConfig[i] = d.copyWith(apertura: t); _emitir(); })),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.4)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(d.apertura.format(context), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: theme.colorScheme.primary)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.arrow_forward, size: 16, color: theme.colorScheme.onSurfaceVariant),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickTime(d.cierre, (t) => setState(() { _diasConfig[i] = d.copyWith(cierre: t); _emitir(); })),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.4)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(d.cierre.format(context), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: theme.colorScheme.primary)),
                    ),
                  ),
                ),
              ] else
                Expanded(
                  child: Text('Cerrado', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic)),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTimeButton(ThemeData theme, String label, TimeOfDay time, ValueChanged<TimeOfDay> onChanged) {
    return InkWell(
      onTap: () => _pickTime(time, onChanged),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(time.format(context), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: theme.colorScheme.primary)),
          ],
        ),
      ),
    );
  }
}

class _DiaConfig {
  final bool abierto;
  final TimeOfDay apertura;
  final TimeOfDay cierre;

  const _DiaConfig({
    required this.abierto,
    required this.apertura,
    required this.cierre,
  });

  _DiaConfig copyWith({bool? abierto, TimeOfDay? apertura, TimeOfDay? cierre}) {
    return _DiaConfig(
      abierto: abierto ?? this.abierto,
      apertura: apertura ?? this.apertura,
      cierre: cierre ?? this.cierre,
    );
  }
}
