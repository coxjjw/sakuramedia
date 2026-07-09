bool isValidHttpUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null &&
      uri.hasScheme &&
      uri.hasAuthority &&
      (uri.scheme == 'http' || uri.scheme == 'https');
}

bool isValidProxyUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null &&
      uri.hasScheme &&
      uri.hasAuthority &&
      (uri.scheme == 'http' ||
          uri.scheme == 'https' ||
          uri.scheme == 'socks5' ||
          uri.scheme == 'socks5h');
}

bool isValidHostname(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty ||
      trimmed.contains(RegExp(r'\s')) ||
      trimmed.contains('://') ||
      trimmed.contains('/') ||
      trimmed.contains('?') ||
      trimmed.contains('#') ||
      trimmed.contains(':')) {
    return false;
  }
  if (trimmed == 'localhost') {
    return true;
  }
  if (_isValidIpv4(trimmed)) {
    return true;
  }
  return _hostnamePattern.hasMatch(trimmed);
}

final RegExp _hostnamePattern = RegExp(
  r'^(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,}$',
);

bool _isValidIpv4(String value) {
  final parts = value.split('.');
  if (parts.length != 4) {
    return false;
  }
  for (final part in parts) {
    if (part.isEmpty || part.length > 3) {
      return false;
    }
    final parsed = int.tryParse(part);
    if (parsed == null || parsed < 0 || parsed > 255) {
      return false;
    }
  }
  return true;
}
