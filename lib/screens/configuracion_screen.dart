import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../database/negocio_dao.dart';
import '../services/tema_service.dart';
import '../services/tema_mapa_service.dart';
import '../services/radio_busqueda_service.dart';

class ConfiguracionScreen extends StatefulWidget {
  const ConfiguracionScreen({super.key});

  @override
  State<ConfiguracionScreen> createState() => _ConfiguracionScreenState();
}

class _ConfiguracionScreenState extends State<ConfiguracionScreen> {
  final NegocioDao _negocioDao = NegocioDao();
  bool _notificaciones = true;

  @override
  void initState() {
    super.initState();
    TemaService.modo.addListener(_onThemeChanged);
    RadioBusquedaService.radioKm.addListener(_onRadioChanged);
    TemaMapaService.actual.addListener(_onTemaMapaChanged);
  }

  @override
  void dispose() {
    TemaService.modo.removeListener(_onThemeChanged);
    RadioBusquedaService.radioKm.removeListener(_onRadioChanged);
    TemaMapaService.actual.removeListener(_onTemaMapaChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (mounted) setState(() {});
  }

  void _onRadioChanged() {
    if (mounted) setState(() {});
  }

  void _onTemaMapaChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _limpiarCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpiar caché'),
        content: const Text('Se eliminarán los negocios descargados. ¿Continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Limpiar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    await _negocioDao.limpiarCache();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Caché limpiado')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final temaActual = TemaService.modo.value;
    final temaMapa = TemaMapaService.actual.value;

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('Tema'),
            trailing: CupertinoSlidingSegmentedControl<ThemeMode>(
              children: const {
                ThemeMode.system: Icon(Icons.brightness_auto, size: 18),
                ThemeMode.light: Icon(Icons.light_mode, size: 18),
                ThemeMode.dark: Icon(Icons.dark_mode, size: 18),
              },
              groupValue: temaActual,
              onValueChanged: (v) => TemaService.establecer(v!),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Radio de búsqueda'),
            subtitle: Text('${RadioBusquedaService.radioKm.value.toStringAsFixed(0)} km'),
            trailing: SizedBox(
              width: 150,
              child: Slider(
                value: RadioBusquedaService.radioKm.value,
                min: RadioBusquedaService.minimo,
                max: RadioBusquedaService.maximo,
                divisions: (RadioBusquedaService.maximo - RadioBusquedaService.minimo).round(),
                label: '${RadioBusquedaService.radioKm.value.toStringAsFixed(0)} km',
                onChanged: (v) => RadioBusquedaService.radioKm.value = v,
                onChangeEnd: (v) => RadioBusquedaService.establecer(v),
              ),
            ),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Notificaciones'),
            value: _notificaciones,
            onChanged: (v) => setState(() => _notificaciones = v),
            secondary: const Icon(Icons.notifications),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_sweep),
            title: const Text('Limpiar caché'),
            subtitle: const Text('Elimina negocios descargados'),
            onTap: _limpiarCache,
          ),
          const Divider(),
          ExpansionTile(
            leading: const Icon(Icons.map),
            title: const Text('Tema del mapa'),
            subtitle: Text(TemaMapaService.nombres[temaMapa] ?? temaMapa),
            initiallyExpanded: false,
            children: TemaMapaService.temas.map((tema) => RadioListTile<String>(
              title: Text(TemaMapaService.nombres[tema] ?? tema),
              subtitle: Text('$tema.xml'),
              value: tema,
              groupValue: temaMapa,
              onChanged: (v) { if (v != null) TemaMapaService.establecer(v); },
            )).toList(),
          ),
        ],
      ),
    );
  }
}
