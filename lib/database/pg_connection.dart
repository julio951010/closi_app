import 'package:postgres/postgres.dart';
import '../config/database_config.dart';

/// Abre una conexión a PostgreSQL usando la configuración centralizada en
/// [DatabaseConfig], con SSL deshabilitado (nuestro servidor local no lo
/// soporta). Usar esta función en vez de llamar a [Connection.open]
/// directamente evita repetir el mismo bloque de configuración en cada
/// archivo y asegura que todos los puntos de conexión se mantengan
/// consistentes.
Future<Connection> abrirConexionPostgres() {
  return Connection.open(
    Endpoint(
      host: DatabaseConfig.host,
      port: DatabaseConfig.port,
      database: DatabaseConfig.database,
      username: DatabaseConfig.username,
      password: DatabaseConfig.password,
    ),
    settings: const ConnectionSettings(sslMode: SslMode.disable),
  );
}
