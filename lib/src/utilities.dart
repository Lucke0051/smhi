import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'smhi_base.dart';

///SMHI API category.
enum Category {
  pmp3g,
}

extension CategoryExtension on Category {
  String get value {
    switch (this) {
      case Category.pmp3g:
        return "pmp3g";
      default:
        return "pmp3g";
    }
  }
}

///SMHI API version.
enum Version {
  two,
}

extension VersionExtension on Version {
  int get value {
    switch (this) {
      case Version.two:
        return 2;
      default:
        return 2;
    }
  }
}

enum Unit {
  hectarePascal,
  celcius,
  kilometer,
  degree,
  meterPerSecond,
  percent,
  octas,
  millimeterPerHour,

  /// Precipitation category, Int, 0-6
  category,

  /// Int, 1-27
  code,
}

///A geographical point on the globe stored as a `latitude` and a `longitude`.
class GeoPoint {
  double latitude;
  double longitude;

  GeoPoint(this.latitude, this.longitude);

  @override
  bool operator ==(Object other) {
    return (other is GeoPoint) &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  String toString() {
    return "Latitude: $latitude Longitude: $longitude";
  }

  @override
  int get hashCode => hash2(latitude, longitude);
}

int hash2(dynamic a, dynamic b) =>
    _finish(_combine(_combine(0, a.hashCode), b.hashCode));

int _combine(int hash, int value) {
  hash = 0x1fffffff & (hash + value);
  hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
  return hash ^ (hash >> 6);
}

int _finish(int hash) {
  hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
  hash = hash ^ (hash >> 11);
  return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
}

Uri constructSmhiUri(
    String host, Category category, Version version, Iterable<String> api,
    {Map<String, dynamic>? query}) {
  final List<String> segments = [
    "api",
    "category",
    category.value,
    "version",
    version.value.toString()
  ];
  segments.addAll(api);
  return Uri(
    host: host,
    scheme: "https",
    pathSegments: segments,
    queryParameters: query,
  );
}

double calculateLatLongDistance(
    double lat1, double lon1, double lat2, double lon2) {
  if (lat1 == lat2 && lon1 == lon2) return 0;
  const double p = 0.017453292519943295;
  return 12742 *
      asin(sqrt(0.5 -
          cos((lat2 - lat1) * p) / 2 +
          cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2));
}

List<GeoPoint>? parseGeoJson(String jsonString) {
  final List<GeoPoint> cords = List.empty(growable: true);
  final json = jsonDecode(jsonString);
  if (json != null) {
    for (int i = 0; i < json["coordinates"][0].length; i++) {
      cords.add(
          GeoPoint(json["coordinates"][0][i][1], json["coordinates"][0][i][0]));
    }
  }
  return cords.isEmpty ? null : cords;
}

bool isPointInPolygon(GeoPoint tap, List<GeoPoint> vertices) {
  int intersectCount = 0;
  for (int j = 0; j < vertices.length - 1; j++) {
    if (_rayCastIntersect(tap, vertices[j], vertices[j + 1])) {
      intersectCount++;
    }
  }

  return (intersectCount % 2) == 1;
}

bool _rayCastIntersect(GeoPoint tap, GeoPoint vertA, GeoPoint vertB) {
  final double aY = vertA.latitude;
  final double bY = vertB.latitude;
  final double aX = vertA.longitude;
  final double bX = vertB.longitude;
  final double pY = tap.latitude;
  final double pX = tap.longitude;

  if ((aY > pY && bY > pY) || (aY < pY && bY < pY) || (aX < pX && bX < pX)) {
    return false;
  }

  final double m = (aY - bY) / (aX - bX);
  final double bee = (-aX) * m + aY;
  final double x = (pY - bee) / m;

  return x > pX;
}

Future request(Uri uri, {bool decode = true, bool allowCached = true}) async {
  final SMHICache cache = SMHICache();
  if (allowCached) {
    final String? data = cache.read(uri);
    if (data != null) {
      return decode ? jsonDecode(data) : data;
    }
  }
  final http.Response response =
      await http.get(uri, headers: {"Accept-Encoding": "gzip"});
  if (response.statusCode == 200) {
    cache.add(uri, response.body);
    return decode ? jsonDecode(response.body) : response.body;
  }
}
