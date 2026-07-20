import 'package:flutter/material.dart';
import 'package:postgres/postgres.dart';
import '../database/pg_connection.dart';
import 'package:uuid/uuid.dart';
import '../models/categoria.dart';
import '../services/permisos_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!PermisosService.esAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Panel de administración')),
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Acceso restringido a administradores', style: TextStyle(fontSize: 16)),
          ]),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de administración'),
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Usuarios'),
            Tab(icon: Icon(Icons.store), text: 'Negocios'),
            Tab(icon: Icon(Icons.category), text: 'Categorías'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: const [
          _UsuariosTab(),
          _NegociosTab(),
          _CategoriasTab(),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// Helpers
// ──────────────────────────────────────────────────────────────────

void _snack(BuildContext context, String msg, {bool ok = true}) {
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? Colors.green : Colors.red,
    ));
  }
}

Future<Connection> _db() async {
  return abrirConexionPostgres();
}

// ──────────────────────────────────────────────────────────────────
// USUARIOS
// ──────────────────────────────────────────────────────────────────

class _UsuariosTab extends StatefulWidget {
  const _UsuariosTab();
  @override
  State<_UsuariosTab> createState() => _UsuariosTabState();
}

class _UsuariosTabState extends State<_UsuariosTab> {
  List<Map<String, dynamic>> _usuarios = [];
  bool _cargando = true;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtrados {
    if (_query.isEmpty) return _usuarios;
    final q = _query.toLowerCase();
    return _usuarios.where((u) =>
      (u['nombre'] as String? ?? '').toLowerCase().contains(q) ||
      (u['email'] as String? ?? '').toLowerCase().contains(q)
    ).toList();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      Connection? conn;
      try {
        conn = await _db();
        final results = await conn.execute(Sql.named('SELECT * FROM usuarios ORDER BY creado_en DESC'));
        _usuarios = results.map((r) => r.toColumnMap()).toList();
      } finally {
        await conn?.close();
      }
      _usuarios.sort((a, b) {
        final da = a['creado_en'] as String? ?? '';
        final db = b['creado_en'] as String? ?? '';
        return db.compareTo(da);
      });
    } catch (e) {
      debugPrint('Admin: error cargando usuarios — $e');
    }
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _eliminar(String id) async {
    if (!await _confirmar('eliminar este usuario')) return;
    try {
      Connection? conn;
      try {
        conn = await _db();
        await conn.execute(Sql.named('DELETE FROM usuarios WHERE id = @id'), parameters: {'id': id});
      } finally {
        await conn?.close();
      }
      _snack(context, 'Usuario eliminado');
      _cargar();
    } catch (e) {
      _snack(context, 'Error al eliminar: $e', ok: false);
    }
  }

  Future<void> _editarRol(String id, String rolActual) async {
    final roles = ['admin', 'cliente', 'invitado'];
    final nuevo = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Cambiar rol'),
        children: roles.where((r) => r != rolActual).map((r) => SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, r),
          child: Text(r),
        )).toList(),
      ),
    );
    if (nuevo == null) return;
    try {
      Connection? conn;
      try {
        conn = await _db();
        await conn.execute(Sql.named('UPDATE usuarios SET rol = @rol WHERE id = @id'), parameters: {'rol': nuevo, 'id': id});
      } finally {
        await conn?.close();
      }
      _snack(context, 'Rol cambiado a $nuevo');
      _cargar();
    } catch (e) {
      _snack(context, 'Error: $e', ok: false);
    }
  }

  Future<bool> _confirmar(String accion) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar'),
        content: Text('¿Estás seguro de $accion?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    final lista = _filtrados;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: TextField(
          controller: _searchCtrl,
          decoration: const InputDecoration(
            hintText: 'Buscar usuarios...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
      ),
      Expanded(
        child: lista.isEmpty
            ? Center(child: Text(_query.isNotEmpty ? 'Sin resultados' : 'No hay usuarios'))
            : RefreshIndicator(
                onRefresh: _cargar,
                child: ListView.builder(
                  itemCount: lista.length,
                  itemBuilder: (_, i) {
                    final u = lista[i];
                    return ListTile(
                      leading: CircleAvatar(child: Text(((u['nombre'] as String? ?? '?').isNotEmpty ? (u['nombre'] as String? ?? '?')[0] : '?').toUpperCase())),
                      title: Text(u['nombre'] as String? ?? ''),
                      subtitle: Text('${u['email']}  •  ${u['rol']}'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'rol') _editarRol(u['id'] as String, u['rol'] as String? ?? 'cliente');
                          if (v == 'eliminar') _eliminar(u['id'] as String);
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'rol', child: Text('Cambiar rol')),
                          const PopupMenuItem(value: 'eliminar', child: Text('Eliminar', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                  },
                ),
              ),
      ),
    ]);
  }
}

// ──────────────────────────────────────────────────────────────────
// NEGOCIOS
// ──────────────────────────────────────────────────────────────────

class _NegociosTab extends StatefulWidget {
  const _NegociosTab();
  @override
  State<_NegociosTab> createState() => _NegociosTabState();
}

class _NegociosTabState extends State<_NegociosTab> {
  List<Map<String, dynamic>> _negocios = [];
  bool _cargando = true;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtrados {
    if (_query.isEmpty) return _negocios;
    final q = _query.toLowerCase();
    return _negocios.where((n) =>
      (n['nombre'] as String? ?? '').toLowerCase().contains(q)
    ).toList();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      Connection? conn;
      try {
        conn = await _db();
        final results = await conn.execute(Sql.named('SELECT * FROM negocios ORDER BY creado_en DESC'));
        _negocios = results.map((r) => r.toColumnMap()).toList();
      } finally {
        await conn?.close();
      }
    } catch (e) {
      debugPrint('Admin: error cargando negocios — $e');
    }
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _eliminar(String id) async {
    if (!await _confirmar('eliminar este negocio')) return;
    try {
      Connection? conn;
      try {
        conn = await _db();
        await conn.execute(Sql.named('DELETE FROM negocios WHERE id = @id'), parameters: {'id': id});
      } finally {
        await conn?.close();
      }
      _snack(context, 'Negocio eliminado');
      _cargar();
    } catch (e) {
      _snack(context, 'Error: $e', ok: false);
    }
  }

  Future<void> _editarEstado(String id, String estadoActual) async {
    final estados = ['aprobado', 'pendiente', 'rechazado'];
    final nuevo = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Cambiar estado'),
        children: estados.where((e) => e != estadoActual).map((e) => SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, e),
          child: Text(e),
        )).toList(),
      ),
    );
    if (nuevo == null) return;
    try {
      Connection? conn;
      try {
        conn = await _db();
        await conn.execute(Sql.named('UPDATE negocios SET estado = @estado WHERE id = @id'), parameters: {'estado': nuevo, 'id': id});
      } finally {
        await conn?.close();
      }
      _snack(context, 'Estado cambiado a $nuevo');
      _cargar();
    } catch (e) {
      _snack(context, 'Error: $e', ok: false);
    }
  }

  Future<bool> _confirmar(String accion) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar'),
        content: Text('¿Estás seguro de $accion?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    final lista = _filtrados;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: TextField(
          controller: _searchCtrl,
          decoration: const InputDecoration(
            hintText: 'Buscar negocios...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
      ),
      Expanded(
        child: lista.isEmpty
            ? Center(child: Text(_query.isNotEmpty ? 'Sin resultados' : 'No hay negocios'))
            : RefreshIndicator(
                onRefresh: _cargar,
                child: ListView.builder(
                  itemCount: lista.length,
                  itemBuilder: (_, i) {
                    final n = lista[i];
            return ListTile(
              leading: Icon(Icons.store, color: Theme.of(context).primaryColor),
              title: Text(n['nombre'] as String? ?? ''),
              subtitle: Text('Estado: ${n['estado']}  •  ${n['categoria_id']}'),
              trailing: PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'estado') _editarEstado(n['id'] as String, n['estado'] as String? ?? 'pendiente');
                  if (v == 'eliminar') _eliminar(n['id'] as String);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'estado', child: Text('Cambiar estado')),
                  const PopupMenuItem(value: 'eliminar', child: Text('Eliminar', style: TextStyle(color: Colors.red))),
                ],
              ),
            );
          },
        ),
      ),
    ),
  ]);
}
}

// ──────────────────────────────────────────────────────────────────
// CATEGORÍAS
// ──────────────────────────────────────────────────────────────────

class _CategoriasTab extends StatefulWidget {
  const _CategoriasTab();
  @override
  State<_CategoriasTab> createState() => _CategoriasTabState();
}

class _CategoriasTabState extends State<_CategoriasTab> {
  List<Categoria> _categorias = [];
  bool _cargando = true;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Categoria> get _filtrados {
    if (_query.isEmpty) return _categorias;
    final q = _query.toLowerCase();
    return _categorias.where((c) => c.nombre.toLowerCase().contains(q)).toList();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      Connection? conn;
      try {
        conn = await _db();
        final results = await conn.execute(Sql.named('SELECT * FROM categorias ORDER BY nombre'));
        final data = results.map((r) => r.toColumnMap()).toList();
        _categorias = data.map((m) => Categoria.fromMap(m)).toList();
      } finally {
        await conn?.close();
      }
    } catch (e) {
      debugPrint('Admin: error cargando categorías — $e');
    }
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _agregar() async {
    final ctrl = TextEditingController();
    final nombre = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva categoría'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Nombre'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Agregar')),
        ],
      ),
    );
    if (nombre == null || nombre.isEmpty) return;
    try {
      Connection? conn;
      try {
        conn = await _db();
        final id = const Uuid().v4();
        await conn.execute(
          Sql.named('INSERT INTO categorias (id, nombre, orden) VALUES (@id, @nombre, @orden)'),
          parameters: {'id': id, 'nombre': nombre, 'orden': _categorias.length},
        );
      } finally {
        await conn?.close();
      }
      _snack(context, 'Categoría agregada');
      _cargar();
    } catch (e) {
      _snack(context, 'Error: $e', ok: false);
    }
  }

  Future<void> _editar(Categoria cat) async {
    final ctrl = TextEditingController(text: cat.nombre);
    final nombre = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar categoría'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Nombre'), autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Guardar')),
        ],
      ),
    );
    if (nombre == null || nombre.isEmpty || nombre == cat.nombre) return;
    try {
      Connection? conn;
      try {
        conn = await _db();
        await conn.execute(
          Sql.named('UPDATE categorias SET nombre = @nombre WHERE id = @id'),
          parameters: {'nombre': nombre, 'id': cat.id},
        );
      } finally {
        await conn?.close();
      }
      _snack(context, 'Categoría actualizada');
      _cargar();
    } catch (e) {
      _snack(context, 'Error: $e', ok: false);
    }
  }

  Future<void> _eliminar(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: const Text('¿Estás seguro?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      Connection? conn;
      try {
        conn = await _db();
        await conn.execute(Sql.named('DELETE FROM categorias WHERE id = @id'), parameters: {'id': id});
      } finally {
        await conn?.close();
      }
      _snack(context, 'Categoría eliminada');
      _cargar();
    } catch (e) {
      _snack(context, 'Error: $e', ok: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    final lista = _filtrados;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: TextField(
          controller: _searchCtrl,
          decoration: const InputDecoration(
            hintText: 'Buscar categorías...',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(width: double.infinity, child: OutlinedButton.icon(
          onPressed: _agregar,
          icon: const Icon(Icons.add),
          label: const Text('Agregar categoría'),
        )),
      ),
      Expanded(
        child: lista.isEmpty
            ? Center(child: Text(_query.isNotEmpty ? 'Sin resultados' : 'No hay categorías'))
            : RefreshIndicator(
                onRefresh: _cargar,
                child: ListView.builder(
                  itemCount: lista.length,
                  itemBuilder: (_, i) {
                    final c = lista[i];
                    return ListTile(
                      leading: Icon(Icons.category),
                      title: Text(c.nombre),
                      subtitle: Text('Orden: ${c.orden}'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => _editar(c)),
                        IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), onPressed: () => _eliminar(c.id)),
                      ]),
                    );
                  },
                ),
              ),
      ),
    ]);
  }
}
