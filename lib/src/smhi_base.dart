class SMHICache {
  static final SMHICache _smhiCache = SMHICache._internal();
  Map<Uri, String>? _cache;

  factory SMHICache() => _smhiCache;

  SMHICache._internal();

  void add(Uri uri, String value) {
    _cache ??= <Uri, String>{};
    _cache![uri] = value;
  }

  String? read(Uri uri) {
    if (_cache != null) return _cache![uri];
  }

  void clean() {
    _cache = null;
  }
}
