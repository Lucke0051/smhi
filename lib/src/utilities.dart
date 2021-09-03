import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

const smhiHost = "opendata-download-metfcst.smhi.se";

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

enum Parameter {
  airPressure,
  airTemperature,
  horizontalVisibility,
  windDirection,
  windSpeed,
  relativeHumidity,
  thunderProbability,
  meanValueOfTotalCloudCover,
  meanValueOfLowLevelCloudCover,
  meanValueOfMediumLevelCloudCover,
  meanValueOfHighLevelCloudCover,
  windGustSpeed,
  minimumPrecipitationIntensity,
  maximumPrecitipationIntensity,

  /// Int, -9 or 0-100, if there is no precipitation, the value of the spp parameter will be -9.
  percentOfPrecipitationInFrozenForm,

  ///0: No precipitation
  ///1:	Snow
  ///2:	Snow and rain
  ///3:	Rain
  ///4:	Drizzle
  ///5:	Freezing rain
  ///6:	Freezing drizzle
  precipitationCategory,
  meanPrecitipationIntensity,
  medianPrecitipationIntensity,
  weatherSymbol,
}

extension ParameterExtension on Parameter {
  String get value {
    switch (this) {
      case Parameter.airPressure:
        return "msl";
      case Parameter.airTemperature:
        return "t";
      case Parameter.horizontalVisibility:
        return "vis";
      case Parameter.windDirection:
        return "wd";
      case Parameter.windSpeed:
        return "ws";
      case Parameter.relativeHumidity:
        return "r";
      case Parameter.thunderProbability:
        return "tstm";
      case Parameter.meanValueOfTotalCloudCover:
        return "tcc_mean";
      case Parameter.meanValueOfLowLevelCloudCover:
        return "lcc_mean";
      case Parameter.meanValueOfMediumLevelCloudCover:
        return "mcc_meam";
      case Parameter.meanValueOfHighLevelCloudCover:
        return "hcc_mean";
      case Parameter.windGustSpeed:
        return "gust";
      case Parameter.minimumPrecipitationIntensity:
        return "pmin";
      case Parameter.maximumPrecitipationIntensity:
        return "pmax";
      case Parameter.percentOfPrecipitationInFrozenForm:
        return "spp";
      case Parameter.precipitationCategory:
        return "pcat";
      case Parameter.meanPrecitipationIntensity:
        return "pmean";
      case Parameter.medianPrecitipationIntensity:
        return "pmedian";
      case Parameter.weatherSymbol:
        return "Wsymb2";
      default:
        return "t";
    }
  }

  Unit get unit {
    switch (this) {
      case Parameter.airPressure:
        return Unit.hectarePascal;
      case Parameter.airTemperature:
        return Unit.celcius;
      case Parameter.horizontalVisibility:
        return Unit.kilometer;
      case Parameter.windDirection:
        return Unit.degree;
      case Parameter.windSpeed:
        return Unit.meterPerSecond;
      case Parameter.relativeHumidity:
        return Unit.percent;
      case Parameter.thunderProbability:
        return Unit.percent;
      case Parameter.meanValueOfTotalCloudCover:
        return Unit.octas;
      case Parameter.meanValueOfLowLevelCloudCover:
        return Unit.octas;
      case Parameter.meanValueOfMediumLevelCloudCover:
        return Unit.octas;
      case Parameter.meanValueOfHighLevelCloudCover:
        return Unit.octas;
      case Parameter.windGustSpeed:
        return Unit.meterPerSecond;
      case Parameter.minimumPrecipitationIntensity:
        return Unit.millimeterPerHour;
      case Parameter.maximumPrecitipationIntensity:
        return Unit.millimeterPerHour;
      case Parameter.percentOfPrecipitationInFrozenForm:
        return Unit.percent;
      case Parameter.precipitationCategory:
        return Unit.category;
      case Parameter.meanPrecitipationIntensity:
        return Unit.millimeterPerHour;
      case Parameter.medianPrecitipationIntensity:
        return Unit.millimeterPerHour;
      case Parameter.weatherSymbol:
        return Unit.code;
      default:
        return Unit.celcius;
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

class GeoPoint {
  double latitude;
  double longitude;

  GeoPoint(this.latitude, this.longitude);
}

Uri constructSmhiUri(Category category, Version version, Iterable<String> api) {
  List<String> segments = ["api", "category", category.value, "version", version.value.toString()];
  segments.addAll(api);
  return Uri(
    host: smhiHost,
    scheme: "https",
    pathSegments: segments,
  );
}

double calculateLatLongDistance(lat1, lon1, lat2, lon2) {
  if (lat1 == lat2 && lon1 == lon2) return 0;
  const p = 0.017453292519943295;
  return 12742 * asin(sqrt(0.5 - cos((lat2 - lat1) * p) / 2 + cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2));
}

List<GeoPoint>? parseGeoJson(String jsonString) {
  List<GeoPoint> cords = List.empty(growable: true);
  var json = jsonDecode(jsonString);
  if (json != null) {
    for (int i = 0; i < json["coordinates"][0].length; i++) {
      cords.add(GeoPoint(json["coordinates"][0][i][1], json["coordinates"][0][i][0]));
    }
  }
  return cords.isEmpty ? null : cords;
}

Future<List<GeoPoint>?> getSMHIBounds() async {
  try {
    http.Response response = await http
        .get(constructSmhiUri(Category.pmp3g, Version.two, ["geotype", "polygon.json"]), headers: {HttpHeaders.acceptEncodingHeader: "gzip"});
    if (response.statusCode == 200) {
      return parseGeoJson(response.body);
    }
  } catch (e) {
    print(e);
  }
}

bool isPointInPolygon(GeoPoint tap, List<GeoPoint> vertices) {
  int intersectCount = 0;
  for (int j = 0; j < vertices.length - 1; j++) {
    if (rayCastIntersect(tap, vertices[j], vertices[j + 1])) {
      intersectCount++;
    }
  }

  return ((intersectCount % 2) == 1);
}

bool rayCastIntersect(GeoPoint tap, GeoPoint vertA, GeoPoint vertB) {
  double aY = vertA.latitude;
  double bY = vertB.latitude;
  double aX = vertA.longitude;
  double bX = vertB.longitude;
  double pY = tap.latitude;
  double pX = tap.longitude;

  if ((aY > pY && bY > pY) || (aY < pY && bY < pY) || (aX < pX && bX < pX)) {
    return false;
  }

  double m = (aY - bY) / (aX - bX);
  double bee = (-aX) * m + aY;
  double x = (pY - bee) / m;

  return x > pX;
}
