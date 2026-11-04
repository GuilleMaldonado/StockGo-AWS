bool esHostLocal(String host) {
  host = host.toLowerCase();
  if (host == 'localhost' || host.endsWith('.local')) return true;
  final parts = host.split('.').map(int.tryParse).toList();
  if (parts.length != 4 ||
      parts.any((part) => part == null || part < 0 || part > 255)) {
    return false;
  }
  return parts[0] == 127 ||
      parts[0] == 10 ||
      (parts[0] == 192 && parts[1] == 168) ||
      (parts[0] == 172 && parts[1]! >= 16 && parts[1]! <= 31);
}

/// Rango compartido utilizado por Tailscale. Una IP por sí sola no prueba
/// que el túnel esté activo: requiere código de conexión con vpn explícito.
bool esHostTunel(String host) {
  final partes = host.split('.').map(int.tryParse).toList();
  return partes.length == 4 &&
      partes.every((p) => p != null && p >= 0 && p <= 255) &&
      partes[0] == 100 &&
      partes[1]! >= 64 &&
      partes[1]! <= 127;
}
