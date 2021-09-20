import 'metfcst.dart';
import 'utilities.dart';

///Caches requests, default cache duration is 30 minutes.
class SMHICache {
  static final SMHICache _smhiCache = SMHICache._internal();
  Map<Uri, CacheBase>? _cache;
  List<GeoPoint>? metFcstPoints;
  Duration maxAge = const Duration(minutes: 30);
  int maxLength = 10;

  factory SMHICache() => _smhiCache;

  SMHICache._internal();

  ///Gets the geographical boundray from the SMHI Meteorological Forecasts API.
  Future<void> setMetFcstPoints(Category category, Version version) async {
    final json = await smhiRequest(
      constructMetFcstUri(
        metfcstHost,
        category,
        version,
        ["geotype", "multipoint.json"],
      ),
    );
    if (json != null) {
      metFcstPoints = List.generate(
        json["coordinates"].length,
        (int index) => GeoPoint(
          json["coordinates"][index][1],
          json["coordinates"][index][0],
        ),
      );
    }
  }

  ///Adds a [CacheBase] with the passed `value` to the cache;
  void add(Uri uri, String value) {
    _cache ??= <Uri, CacheBase>{};
    if (_cache!.length >= maxLength) {
      final Map<Uri, CacheBase> map = <Uri, CacheBase>{};
      final List<MapEntry<Uri, CacheBase>> entries = _cache!.entries.toList();
      entries.sort((MapEntry<Uri, CacheBase> a, MapEntry<Uri, CacheBase> b) =>
          a.value.compareTo(b.value));
      map.addEntries(entries.getRange(0, maxLength - 2));
      _cache = map;
    }
    _cache![uri] = CacheBase(value, DateTime.now());
  }

  ///Reads from the cache with the passed `uri`.
  String? read(Uri uri) {
    if (_cache != null) {
      final CacheBase? base = _cache![uri];
      if (base != null && base.age < maxAge) {
        return base.data;
      } else {
        _cache!.remove(uri);
      }
    }
  }

  void clear() {
    _cache = null;
  }
}

class CacheBase {
  late final DateTime added;
  late final String data;

  Duration get age => DateTime.now().difference(added);

  CacheBase(this.data, this.added);

  int compareTo(CacheBase other) => added.compareTo(other.added);
}
