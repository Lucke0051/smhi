import 'package:intl/intl.dart';
import 'smhi_base.dart';
import 'utilities.dart';

/// The SMHI Open Data Meteorological Forecasts API host.
const String metfcstHost = "opendata-download-metfcst.smhi.se";

class MeteorologicalForecasts {
  late final Category category;
  late final Version version;

  MeteorologicalForecasts({
    this.category = Category.pmp3g,
    this.version = Version.two,
  });

  ///The current forecast approved time (the time the forecast latest was updated).
  Future<DateTime?> get approvedTime async {
    final json = await request(constructSmhiUri(
        metfcstHost, category, version, ["approvedtime.json"]));
    if (json != null) {
      return DateTime.tryParse(json["referenceTime"]);
    }
  }

  ///The valid times for the current forecast. In the answer you get the valid time list.
  Future<List<DateTime>?> get validTime async {
    final json = await request(
        constructSmhiUri(metfcstHost, category, version, ["validtime.json"]));
    if (json != null) {
      final List<DateTime> validTime = List.empty(growable: true);
      for (final String time in json["validTime"]) {
        final DateTime? date = DateTime.tryParse(time);
        if (date != null) validTime.add(date);
      }
      return validTime;
    }
  }

  ///The valid times for the current multipoint forecast. In the answer you get the valid time list. You can use the list to specify what valid time when getting a [MultiPointForecast] with [multiPointForecast].
  Future<List<DateTime>?> get multiPointValidTime async {
    final json = await request(constructSmhiUri(metfcstHost, category, version,
        ["geotype", "multipoint", "validtime.json"]));
    if (json != null) {
      final List<DateTime> validTime = List.empty(growable: true);
      for (final String time in json["validTime"]) {
        final DateTime? date = DateTime.tryParse(time);
        if (date != null) validTime.add(date);
      }
      return validTime;
    }
  }

  ///The bounding box polygon for the [Forecast] and [MultiPointForecast] area.
  Future<List<GeoPoint>?> getSMHIBounds() async {
    final String? data = await request(
        constructSmhiUri(metfcstHost, Category.pmp3g, Version.two,
            ["geotype", "polygon.json"]),
        decode: false);
    if (data != null) {
      return parseGeoJson(data);
    }
  }

  ///Returns a complete [Forecast] approximately 10 days ahead of the latest current forecast. All times in the answer given in UTC.
  ///
  ///For example, to get the air temperature tomorrow at Stockholm (Latitude: 59.334591, longitude: 18.063240), you could do the following:
  ///
  ///```dart
  ///final MeteorologicalForecasts meteorologicalForecasts = MeteorologicalForecasts();
  ///final Forecast? forecast = await meteorologicalForecasts.forecast(GeoPoint(59.334591, 18.063240));
  ///if (forecast != null) {
  ///  final ForecastMoment moment = forecast.momentWhen(DateTime.now().add(const Duration(days: 1)));
  ///  print(moment.valueOf(MetFcstParameter.airTemperature));
  ///}
  ///```
  Future<Forecast?> forecast(GeoPoint point) async {
    final json =
        await request(constructSmhiUri(metfcstHost, category, version, [
      "geotype",
      "point",
      "lon",
      point.longitude.toStringAsFixed(6),
      "lat",
      point.latitude.toStringAsFixed(6),
      "data.json",
    ]));
    if (json != null) {
      return Forecast.fromJson(json);
    }
  }

  ///Returns a [MultiPointForecast] which contains a forecast for all grid points with the specified [parameter], [levelType] and [level].
  ///
  ///The parameter [downsample] allows an integer between 0-20. A downsample value of 2 means that every other value horizontally and vertically is displayed.
  ///
  ///`points` are automatically stored in the [SMHICache] if there is no `points` there already.
  Future<MultiPointForecast?> multiPointForecast(DateTime validTime,
      MetFcstParameter parameter, MetFcstLevelType levelType, int level,
      {int? downsample}) async {
    final SMHICache cache = SMHICache();
    final DateFormat formatter = DateFormat("yyyyMMdd'T'HHmmss'Z'");
    final json =
        await request(constructSmhiUri(metfcstHost, category, version, [
      "geotype",
      "multipoint",
      "validtime",
      formatter.format(validTime),
      "parameter",
      parameter.value,
      "leveltype",
      levelType.value,
      "level",
      level.toString(),
      "data.json"
    ], query: {
      "with-geo": (cache.metFcstPoints == null).toString(),
      "downsample": downsample != null ? downsample.toString() : "2",
    }));
    if (json != null) {
      if (json["geometry"] != null) {
        cache.metFcstPoints = List.generate(
            json["geometry"]["coordinates"].length,
            (int index) => GeoPoint(json["geometry"]["coordinates"][index][1],
                json["geometry"]["coordinates"][index][0]));
      }
      return MultiPointForecast.fromJson(json);
    }
  }
}

class Forecast {
  late final DateTime approvedTime;
  late final DateTime referenceTime;
  late final GeoPoint point;
  late final List<ForecastMoment> timeSeries;

  Forecast({
    required this.approvedTime,
    required this.referenceTime,
    required this.point,
    required this.timeSeries,
  });

  factory Forecast.fromJson(json) => Forecast(
        approvedTime: DateTime.parse(json["approvedTime"]),
        referenceTime: DateTime.parse(json["referenceTime"]),
        point: GeoPoint(json["geometry"]["coordinates"][0][1],
            json["geometry"]["coordinates"][0][0]),
        timeSeries: List.generate(json["timeSeries"].length,
            (int index) => ForecastMoment.fromJson(json["timeSeries"][index])),
      );

  ///Returns the [ForecastMoment] closest to the specified [date].
  ForecastMoment momentWhen(DateTime date) =>
      timeSeries.reduce((ForecastMoment value, ForecastMoment element) =>
          value.validTime.difference(date) < element.validTime.difference(date)
              ? value
              : element);
}

//Forecasts are divided into moments where each [ForecastMoment] represents a timestamp.
class ForecastMoment {
  late final DateTime validTime;
  late final Map<String, Map<String, dynamic>> _parameters;

  dynamic valueOf(MetFcstParameter parameter, {int? index}) {
    return _parameters[parameter.value]!["values"][index ?? 0];
  }

  String levelTypeOf(MetFcstParameter parameter, {int? index}) {
    return _parameters[parameter.value]!["levelType"];
  }

  int levelOf(MetFcstParameter parameter, {int? index}) {
    return int.parse(_parameters[parameter.value]!["level"]);
  }

  ForecastMoment(
    this.validTime,
    this._parameters,
  );

  factory ForecastMoment.fromJson(json) {
    final Map<String, Map<String, dynamic>> params = {};
    for (final Map<String, dynamic> param in json["parameters"]) {
      params[param["name"]] = param;
    }
    return ForecastMoment(
      DateTime.parse(json["validTime"]),
      params,
    );
  }
}

///The index for each value in `values` matches the index for the points in [SMHICache.metFcstPoints].
class MultiPointForecast {
  late final DateTime approvedTime;
  late final DateTime referenceTime;
  late final List values;

  MultiPointForecast({
    required this.approvedTime,
    required this.referenceTime,
    required this.values,
  });

  factory MultiPointForecast.fromJson(json) {
    return MultiPointForecast(
      approvedTime: DateTime.parse(json["approvedTime"]),
      referenceTime: DateTime.parse(json["referenceTime"]),
      values: json["timeSeries"] != null && json["timeSeries"].isNotEmpty
          ? json["timeSeries"][0]["parameters"][0]["values"]
          : [],
    );
  }

  ///Gets the value `at` the specificed [GeoPoint].
  dynamic valueAt(GeoPoint at, {List<GeoPoint>? points}) {
    points ??= SMHICache().metFcstPoints!;
    int? closestIndex;
    double? closestDistance;
    for (int i = 0; i < points.length; i++) {
      final GeoPoint point = points[i];
      final double distance = calculateLatLongDistance(
          at.latitude, at.longitude, point.latitude, point.longitude);
      if ((closestIndex == null) || (closestDistance! > distance)) {
        closestIndex = i;
        closestDistance = distance;
      }
    }
    if (closestIndex != null) {
      return values[closestIndex];
    }
  }
}

///Parameters for [MeteorologicalForecasts], see: https://opendata.smhi.se/apidocs/metfcst/parameters.html
enum MetFcstParameter {
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

extension MetFcstParameterExtension on MetFcstParameter {
  String get value {
    switch (this) {
      case MetFcstParameter.airPressure:
        return "msl";
      case MetFcstParameter.airTemperature:
        return "t";
      case MetFcstParameter.horizontalVisibility:
        return "vis";
      case MetFcstParameter.windDirection:
        return "wd";
      case MetFcstParameter.windSpeed:
        return "ws";
      case MetFcstParameter.relativeHumidity:
        return "r";
      case MetFcstParameter.thunderProbability:
        return "tstm";
      case MetFcstParameter.meanValueOfTotalCloudCover:
        return "tcc_mean";
      case MetFcstParameter.meanValueOfLowLevelCloudCover:
        return "lcc_mean";
      case MetFcstParameter.meanValueOfMediumLevelCloudCover:
        return "mcc_meam";
      case MetFcstParameter.meanValueOfHighLevelCloudCover:
        return "hcc_mean";
      case MetFcstParameter.windGustSpeed:
        return "gust";
      case MetFcstParameter.minimumPrecipitationIntensity:
        return "pmin";
      case MetFcstParameter.maximumPrecitipationIntensity:
        return "pmax";
      case MetFcstParameter.percentOfPrecipitationInFrozenForm:
        return "spp";
      case MetFcstParameter.precipitationCategory:
        return "pcat";
      case MetFcstParameter.meanPrecitipationIntensity:
        return "pmean";
      case MetFcstParameter.medianPrecitipationIntensity:
        return "pmedian";
      case MetFcstParameter.weatherSymbol:
        return "Wsymb2";
      default:
        return "t";
    }
  }

  ///The [Unit] for the [MetFcstParameter]'s value.
  Unit get unit {
    switch (this) {
      case MetFcstParameter.airPressure:
        return Unit.hectarePascal;
      case MetFcstParameter.airTemperature:
        return Unit.celcius;
      case MetFcstParameter.horizontalVisibility:
        return Unit.kilometer;
      case MetFcstParameter.windDirection:
        return Unit.degree;
      case MetFcstParameter.windSpeed:
        return Unit.meterPerSecond;
      case MetFcstParameter.relativeHumidity:
        return Unit.percent;
      case MetFcstParameter.thunderProbability:
        return Unit.percent;
      case MetFcstParameter.meanValueOfTotalCloudCover:
        return Unit.octas;
      case MetFcstParameter.meanValueOfLowLevelCloudCover:
        return Unit.octas;
      case MetFcstParameter.meanValueOfMediumLevelCloudCover:
        return Unit.octas;
      case MetFcstParameter.meanValueOfHighLevelCloudCover:
        return Unit.octas;
      case MetFcstParameter.windGustSpeed:
        return Unit.meterPerSecond;
      case MetFcstParameter.minimumPrecipitationIntensity:
        return Unit.millimeterPerHour;
      case MetFcstParameter.maximumPrecitipationIntensity:
        return Unit.millimeterPerHour;
      case MetFcstParameter.percentOfPrecipitationInFrozenForm:
        return Unit.percent;
      case MetFcstParameter.precipitationCategory:
        return Unit.category;
      case MetFcstParameter.meanPrecitipationIntensity:
        return Unit.millimeterPerHour;
      case MetFcstParameter.medianPrecitipationIntensity:
        return Unit.millimeterPerHour;
      case MetFcstParameter.weatherSymbol:
        return Unit.code;
      default:
        return Unit.celcius;
    }
  }
}

///There are two level types, `hmsl` and `hl`. `hmsl` means mean sea level and `hl` means level above ground.
enum MetFcstLevelType { hmsl, hl }

extension MetFcstLevelTypeExtension on MetFcstLevelType {
  String get value {
    switch (this) {
      case MetFcstLevelType.hl:
        return "hl";
      case MetFcstLevelType.hmsl:
        return "hmsl";
      default:
        return "hl";
    }
  }
}
