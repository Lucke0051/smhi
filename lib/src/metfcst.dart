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
    final json = await smhiRequest(constructMetFcstUri(metfcstHost, category, version, ["approvedtime.json"]));
    if (json != null) {
      return DateTime.tryParse(json["referenceTime"]);
    }
  }

  ///The valid times for the current forecast. In the answer you get the valid time list.
  Future<List<DateTime>?> get validTime async {
    final json = await smhiRequest(constructMetFcstUri(metfcstHost, category, version, ["validtime.json"]));
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
    final json = await smhiRequest(constructMetFcstUri(metfcstHost, category, version, ["geotype", "multipoint", "validtime.json"]));
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
    final String? data = await smhiRequest(constructMetFcstUri(metfcstHost, Category.pmp3g, Version.two, ["geotype", "polygon.json"]), decode: false);
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
  Future<Forecast?> forecast(GeoPoint point, {bool allowCached = true}) async {
    final json = await smhiRequest(
      constructMetFcstUri(metfcstHost, category, version, [
        "geotype",
        "point",
        "lon",
        point.longitude.toStringAsFixed(6),
        "lat",
        point.latitude.toStringAsFixed(6),
        "data.json",
      ]),
      allowCached: allowCached,
    );
    if (json != null) {
      return Forecast.fromJson(json);
    }
  }

  ///Returns a [MultiPointForecast] which contains a forecast for all grid points with the specified [parameter], [levelType] and [level].
  ///
  ///The parameter [downsample] allows an integer between 0-20. A downsample value of 2 means that every other value horizontally and vertically is displayed.
  ///
  ///`points` are automatically stored in the [SMHICache] if there is no `points` there already.
  Future<MultiPointForecast?> multiPointForecast(DateTime validTime, MetFcstParameter parameter, MetFcstLevelType levelType, int level,
      {int? downsample, bool allowCached = true}) async {
    final SMHICache cache = SMHICache();
    final DateFormat formatter = DateFormat("yyyyMMdd'T'HHmmss'Z'");
    final json = await smhiRequest(
      constructMetFcstUri(
        metfcstHost,
        category,
        version,
        [
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
        ],
        query: {
          "with-geo": (cache.metFcstPoints == null).toString(),
          "downsample": downsample != null ? downsample.toString() : "2",
        },
      ),
      allowCached: allowCached,
    );
    if (json != null) {
      if (json["geometry"] != null) {
        cache.metFcstPoints = List.generate(
          json["geometry"]["coordinates"].length,
          (int index) => GeoPoint(json["geometry"]["coordinates"][index][1], json["geometry"]["coordinates"][index][0]),
        );
      }
      return MultiPointForecast.fromJson(json);
    }
  }

  static MetFcstParameter? toParameter(String string) {
    switch (string) {
      case "msl":
        return MetFcstParameter.airPressure;
      case "t":
        return MetFcstParameter.airTemperature;
      case "vis":
        return MetFcstParameter.horizontalVisibility;
      case "wd":
        return MetFcstParameter.windDirection;
      case "ws":
        return MetFcstParameter.windSpeed;
      case "r":
        return MetFcstParameter.relativeHumidity;
      case "tstm":
        return MetFcstParameter.thunderProbability;
      case "tcc_mean":
        return MetFcstParameter.meanValueOfTotalCloudCover;
      case "lcc_mean":
        return MetFcstParameter.meanValueOfLowLevelCloudCover;
      case "mcc_meam":
        return MetFcstParameter.meanValueOfMediumLevelCloudCover;
      case "hcc_mean":
        return MetFcstParameter.meanValueOfHighLevelCloudCover;
      case "gust":
        return MetFcstParameter.windGustSpeed;
      case "pmin":
        return MetFcstParameter.minimumPrecipitationIntensity;
      case "pmax":
        return MetFcstParameter.maximumPrecipitationIntensity;
      case "spp":
        return MetFcstParameter.percentOfPrecipitationInFrozenForm;
      case "pcat":
        return MetFcstParameter.precipitationCategory;
      case "pmean":
        return MetFcstParameter.meanPrecipitationIntensity;
      case "pmedian":
        return MetFcstParameter.medianPrecipitationIntensity;
      case "Wsymb2":
        return MetFcstParameter.weatherSymbol;
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
        point: GeoPoint(json["geometry"]["coordinates"][0][1], json["geometry"]["coordinates"][0][0]),
        timeSeries: List.generate(json["timeSeries"].length, (int index) => ForecastMoment.fromJson(json["timeSeries"][index])),
      );

  ///Returns the [ForecastMoment] closest to the specified [date].
  ForecastMoment momentWhen(DateTime date) => timeSeries.reduce(
        (ForecastMoment value, ForecastMoment element) => value.validTime.difference(date) < element.validTime.difference(date) ? value : element,
      );

  ///Returns the [ForecastMoment] closest to the specified [date] after [after].
  ForecastMoment momentWhenAfter(DateTime date, DateTime after) {
    final List<ForecastMoment> afterTimeSeries = List.empty(growable: true);
    for (final ForecastMoment moment in timeSeries) {
      if (moment.validTime.isAfter(after)) afterTimeSeries.add(moment);
    }
    return afterTimeSeries.reduce(
      (ForecastMoment value, ForecastMoment element) => value.validTime.difference(date) < element.validTime.difference(date) ? value : element,
    );
  }

  ///Returns the [ForecastMoment] closest to the specified [date] before [before].
  ForecastMoment momentWhenBefore(DateTime date, DateTime before) {
    final List<ForecastMoment> afterTimeSeries = List.empty(growable: true);
    for (final ForecastMoment moment in timeSeries) {
      if (moment.validTime.isBefore(before)) afterTimeSeries.add(moment);
    }
    return afterTimeSeries.reduce(
      (ForecastMoment value, ForecastMoment element) => value.validTime.difference(date) < element.validTime.difference(date) ? value : element,
    );
  }

  ///Returns [ForecastMoment]s after `after` and before `before`.
  List<ForecastMoment> momentsBetween(DateTime after, {DateTime? before}) {
    final List<ForecastMoment> moments = List.empty(growable: true);
    for (final ForecastMoment moment in timeSeries) {
      if (moment.validTime.isAfter(after) && (before == null || moment.validTime.isBefore(before))) moments.add(moment);
    }
    return moments;
  }

  ///Returns the mode value of the specified [parameter] in [moments];
  static double modeOf(MetFcstParameter parameter, List<ForecastMoment> moments) {
    final List<double> values = List.empty(growable: true);
    for (final ForecastMoment element in moments) {
      values.add(element.valueOf(parameter));
    }
    return _mode(values);
  }

  ///Returns the type value value of the specified [parameter] in [moments];
  static double averageOf(MetFcstParameter parameter, List<ForecastMoment> moments) {
    double value = 0;
    for (final ForecastMoment element in moments) {
      value += element.valueOf(parameter);
    }
    return value / moments.length;
  }

  ///Returns the lowest value of the specified [parameter] in [moments];
  static double lowestOf(MetFcstParameter parameter, List<ForecastMoment> moments) {
    double? value;
    for (final ForecastMoment element in moments) {
      final double elementValue = element.valueOf(parameter);
      if (value == null || value > elementValue) {
        value = elementValue;
      }
    }
    return value!;
  }

  ///Returns the highest value of the specified [parameter] in [moments];
  static double highestOf(MetFcstParameter parameter, List<ForecastMoment> moments) {
    double? value;
    for (final ForecastMoment element in moments) {
      final double elementValue = element.valueOf(parameter);
      if (value == null || value < elementValue) {
        value = elementValue;
      }
    }
    return value!;
  }
}

//Forecasts are divided into moments where each [ForecastMoment] represents a timestamp.
class ForecastMoment {
  late final DateTime validTime;
  late final Map<String, Map<String, dynamic>> _parameters;
  final Map<MetFcstParameter, double> _values = <MetFcstParameter, double>{};

  double valueOf(MetFcstParameter parameter, {int? index}) {
    if (_values[parameter] != null) {
      return _values[parameter]!;
    }
    final double value = double.parse(_parameters[parameter.value]!["values"][index ?? 0].toString());
    _values[parameter] = value;
    return value;
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
      values: json["timeSeries"] != null && json["timeSeries"].isNotEmpty ? json["timeSeries"][0]["parameters"][0]["values"] : [],
    );
  }

  ///Gets the value `at` the specificed [GeoPoint].
  dynamic valueAt(GeoPoint at, {List<GeoPoint>? points}) {
    points ??= SMHICache().metFcstPoints!;
    int? closestIndex;
    double? closestDistance;
    for (int i = 0; i < points.length; i++) {
      final GeoPoint point = points[i];
      final double distance = calculateLatLongDistance(at.latitude, at.longitude, point.latitude, point.longitude);
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
  maximumPrecipitationIntensity,

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
  meanPrecipitationIntensity,
  medianPrecipitationIntensity,
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
      case MetFcstParameter.maximumPrecipitationIntensity:
        return "pmax";
      case MetFcstParameter.percentOfPrecipitationInFrozenForm:
        return "spp";
      case MetFcstParameter.precipitationCategory:
        return "pcat";
      case MetFcstParameter.meanPrecipitationIntensity:
        return "pmean";
      case MetFcstParameter.medianPrecipitationIntensity:
        return "pmedian";
      case MetFcstParameter.weatherSymbol:
        return "Wsymb2";
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
        return Unit.okta;
      case MetFcstParameter.meanValueOfLowLevelCloudCover:
        return Unit.okta;
      case MetFcstParameter.meanValueOfMediumLevelCloudCover:
        return Unit.okta;
      case MetFcstParameter.meanValueOfHighLevelCloudCover:
        return Unit.okta;
      case MetFcstParameter.windGustSpeed:
        return Unit.meterPerSecond;
      case MetFcstParameter.minimumPrecipitationIntensity:
        return Unit.millimeterPerHour;
      case MetFcstParameter.maximumPrecipitationIntensity:
        return Unit.millimeterPerHour;
      case MetFcstParameter.percentOfPrecipitationInFrozenForm:
        return Unit.percent;
      case MetFcstParameter.precipitationCategory:
        return Unit.category;
      case MetFcstParameter.meanPrecipitationIntensity:
        return Unit.millimeterPerHour;
      case MetFcstParameter.medianPrecipitationIntensity:
        return Unit.millimeterPerHour;
      case MetFcstParameter.weatherSymbol:
        return Unit.code;
    }
  }

  ///Returns if the [value] is valid for the [MetFcstParameter]. Null if no validation check is avalible for the [MetFcstParameter].
  ///
  ///See: https://opendata.smhi.se/apidocs/metfcst/parameters.html
  bool? validate(double value) {
    switch (this) {
      case MetFcstParameter.relativeHumidity:
        return value >= 0 && value <= 100;
      case MetFcstParameter.thunderProbability:
        return value >= 0 && value <= 100;
      case MetFcstParameter.meanValueOfTotalCloudCover:
        return value >= 0 && value <= 8 && value.roundToDouble() == value;
      case MetFcstParameter.meanValueOfLowLevelCloudCover:
        return value >= 0 && value <= 8 && value.roundToDouble() == value;
      case MetFcstParameter.meanValueOfMediumLevelCloudCover:
        return value >= 0 && value <= 8 && value.roundToDouble() == value;
      case MetFcstParameter.meanValueOfHighLevelCloudCover:
        return value >= 0 && value <= 8 && value.roundToDouble() == value;
      case MetFcstParameter.percentOfPrecipitationInFrozenForm:
        return value == -9 || (value >= 0 && value <= 100);
      case MetFcstParameter.precipitationCategory:
        return value >= 0 && value <= 6 && value.roundToDouble() == value;
      case MetFcstParameter.weatherSymbol:
        return value >= 1 && value <= 27 && value.roundToDouble() == value;
      default:
        return null;
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

double _mode(List<double> a) {
  double maxValue = 0.0;
  int maxCount = 0;

  for (int i = 0; i < a.length; ++i) {
    int count = 0;
    for (int j = 0; j < a.length; ++j) {
      if (a[j] == a[i]) ++count;
    }
    if (count > maxCount) {
      maxCount = count;
      maxValue = a[i];
    }
  }
  return maxValue;
}

Uri constructMetFcstUri(String host, Category category, Version version, Iterable<String> api, {Map<String, dynamic>? query}) {
  final List<String> segments = ["api", "category", category.value, "version", version.value.toString()];
  segments.addAll(api);
  return Uri(
    host: host,
    scheme: "https",
    pathSegments: segments,
    queryParameters: query,
  );
}
