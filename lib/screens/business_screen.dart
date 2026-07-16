import 'dart:async';
import 'package:flutter/material.dart';
import '../database/negocio_dao.dart';
import '../models/negocio.dart';
import '../services/permisos_service.dart';
import '../services/sesion_service.dart';
import '../services/sync_service.dart';
import 'admin_negocio_screen.dart';
import 'agregar_negocio_screen.dart';

class BusinessScreen extends StatefulWidget {
  const BusinessScreen({super.key});

  @override
  State<BusinessScreen> createState() => _BusinessScreenState();
}

class _BusinessScreenState extends State<BusinessScreen> {
  final NegocioDao _negocioDao = NegocioDao();
  List<Negocio> _misNegocios = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarNegocios();
  }

  Future<void> _cargarNegocios() async {
    try {
      final negocios = await _negocioDao.obtenerPropios(SesionService.usuarioId);
      if (mounted) {
        setState(() {
          _misNegocios = negocios;
          _cargando = false;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar negocios propios: $e');
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _eliminarNegocio(Negocio negocio) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar negocio'),
        content: Text('¿Eliminar "${negocio.nombre}"?'),
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
      await _negocioDao.eliminarPropio(negocio.id);
      unawaited(SyncService.sincronizar());
      _cargarNegocios();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (PermisosService.esInvitado) {
      return Scaffold(
        appBar: AppBar(title: const Text('Negocios')),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Negocios')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1565C0)))
          : _misNegocios.isEmpty
              ? _buildEmptyState()
              : _buildList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const AgregarNegocioScreen()));
          _cargarNegocios();
        },
        icon: const Icon(Icons.add),
        label: const Text('Agregar negocio'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.store, size: 80, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text('Gestiona tu negocio', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Agrega y administra tus negocios', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
        ],
      ),
    );
  }

  Widget _buildList() {
    return RefreshIndicator(
      onRefresh: _cargarNegocios,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _misNegocios.length,
        itemBuilder: (context, index) {
          final n = _misNegocios[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              onTap: () async {
                final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => AdminNegocioScreen(negocio: n)));
                if (changed == true) _cargarNegocios();
              },
              contentPadding: const EdgeInsets.all(12),
              leading: Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Negocio.getIcono(n.categoria), color: Theme.of(context).primaryColor),
              ),
              title: Text(n.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(Negocio.getNombreCategoria(n.categoria)),
                  if (n.estado != 'aprobado')
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(n.estado == 'pendiente' ? 'Pendiente' : n.estado,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8), fontSize: 11)),
                    ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _eliminarNegocio(n),
              ),
            ),
          );
        },
      ),
    );
  }
}
