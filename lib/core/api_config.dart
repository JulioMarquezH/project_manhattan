/// Configuración de conexión al backend real.
///
/// El backend vive en un servidor propio con dominio fijo.
/// Health check: https://api.manhattan-project.online/health
///
/// Para apuntar a otro backend (p. ej. uno local) sin tocar el código:
///   flutter run -d chrome --dart-define=API_HOST=localhost:8000 --dart-define=API_INSECURE=true
class ApiConfig {
  /// Host del backend, SIN esquema (http/https) ni barra final.
  static const String host = String.fromEnvironment(
    'API_HOST',
    defaultValue: 'api.manhattan-project.online',
  );

  /// true solo para desarrollo local sin HTTPS.
  static const bool _insecure = bool.fromEnvironment('API_INSECURE');

  static const String baseUrl = '${_insecure ? 'http' : 'https'}://$host/api';
  static const String wsBaseUrl = '${_insecure ? 'ws' : 'wss'}://$host/ws';
}
