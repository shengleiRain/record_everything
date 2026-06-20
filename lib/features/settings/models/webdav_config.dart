class WebDavConfig {
  const WebDavConfig({
    required this.serverUrl,
    required this.username,
    required this.password,
    required this.remotePath,
  });

  final String serverUrl;
  final String username;
  final String password;
  final String remotePath;

  /// Returns [serverUrl] without trailing slash.
  String get baseUrl => serverUrl.endsWith('/')
      ? serverUrl.substring(0, serverUrl.length - 1)
      : serverUrl;

  /// Returns [remotePath] with leading slash, without trailing slash.
  String get normalizedPath {
    var p = remotePath;
    if (!p.startsWith('/')) p = '/$p';
    if (p.endsWith('/') && p.length > 1) {
      p = p.substring(0, p.length - 1);
    }
    return p;
  }
}
