class ApiConfig {
  ApiConfig._();

  /// Servidor de SIDE B. Se puede configurar al compilar con API_BASE_URL.
  static const List<String> baseUrls = [
    String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://192.168.3.22:8000',
    ),
  ];

  static String get baseUrl => baseUrls.first;

  static String? mediaUrl(String? value) {
    if (value == null || value.isEmpty) return value;
    final uri = Uri.parse(value);
    final server = Uri.parse(baseUrl);
    if (!uri.hasAuthority) return server.resolveUri(uri).toString();
    if (uri.host == '127.0.0.1' || uri.host == 'localhost' || uri.host == '::1') {
      return uri.replace(
        scheme: server.scheme,
        host: server.host,
        port: server.hasPort ? server.port : null,
      ).toString();
    }
    return value;
  }
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
