import 'metfcst.dart';
import 'utilities.dart';

///Caches requests, default cache duration is 30 minutes.
class SMHICache {
  static final SMHICache _smhiCache = SMHICache._internal();
  Map<Uri, CacheBase>? _cache;
  final List<Function> _onAddCallbacks = List.empty(growable: true);
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
      entries.sort((MapEntry<Uri, CacheBase> a, MapEntry<Uri, CacheBase> b) => a.value.compareTo(b.value));
      map.addEntries(entries.getRange(0, maxLength - 2));
      _cache = map;
    }
    _cache![uri] = CacheBase(value, DateTime.now());
    for (final Function function in _onAddCallbacks) {
      function(uri);
    }
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

  Map<Uri, CacheBase>? get allCached => _cache;

  ///Clears the cache
  void clear() {
    _cache = null;
  }

  Map<String, dynamic> toJson() {
    final List<Map<String, dynamic>> cacheList = List.empty(growable: true);
    if (_cache != null) {
      _cache!.forEach((Uri key, CacheBase value) {
        cacheList.add({
          "u": key.toString(),
          "b": value.toJson(),
        });
      });
    }
    return {
      "at": DateTime.now().toUtc().millisecondsSinceEpoch,
      "mfcp": metFcstPoints != null
          ? List.generate(
              metFcstPoints!.length,
              (int index) => {
                "lat": metFcstPoints![index].latitude,
                "lon": metFcstPoints![index].longitude,
              },
            )
          : null,
      "c": cacheList,
    };
  }

  void fromJson(Map<String, dynamic> json, {Duration? maxAge}) {
    final Duration age = Duration(milliseconds: DateTime.now().toUtc().millisecondsSinceEpoch - json["at"] as int);
    if (maxAge == null || age < maxAge) {
      if (json["mfcp"] != null) {
        metFcstPoints = List.generate(json["mfcp"].length, (int index) => GeoPoint(json["mfcp"][index]["lat"], json["mfcp"][index]["lon"]));
      }
      if (json["c"] != null) {
        _cache ??= {};
        for (final Map<String, dynamic> map in json["c"]) {
          _cache![Uri.parse(map["u"])] = map["b"];
        }
      }
    }
  }

  ///The [function] passed will be called with the [Uri] of the data added every time data is added to the cache.
  ///
  ///The data can then be read by calling [read] with the [Uri].
  void registerOnAddCallback(Function function) => _onAddCallbacks.add(function);
}

class CacheBase {
  late final DateTime added;
  late final String data;

  Duration get age => DateTime.now().difference(added);

  CacheBase(this.data, this.added);

  int compareTo(CacheBase other) => added.compareTo(other.added);

  Map<String, String> toJson() => {"a": added.toIso8601String(), "d": data};

  factory CacheBase.fromJson(Map<String, String> json) => CacheBase(json["a"]!, DateTime.parse(json["d"]!));
}
