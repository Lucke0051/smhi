import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'utilities.dart';

const metfcstHost = "opendata-download-metfcst.smhi.se";

/// Meteorological Forecasts
class MeteorologicalForecasts {
  late final Category category;
  late final Version version;
  List<GeoPoint> _points;

  //TODO: setter _points & getter

  MeteorologicalForecasts({
    required this.category,
    required this.version,
  });

  ///The current forecast approved time (the time the forecast latest was updated)
  Future<DateTime?> get approvedTime async {
    try {
      http.Response response = await http
          .get(constructSmhiUri(metfcstHost, category, version, ["approvedtime.json"]), headers: {HttpHeaders.acceptEncodingHeader: "gzip"});
      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);
        return DateTime.tryParse(json["referenceTime"]);
      }
    } catch (e) {
      print(e);
    }
  }

  ///The valid times for the current forecast. In the answer you get the valid time list. You can use the list to specify what valid time when getting a [MultiPointForecast] with [multiPointForecast].
  Future<List<DateTime>?> get validTime async {
    try {
      http.Response response =
          await http.get(constructSmhiUri(metfcstHost, category, version, ["validtime.json"]), headers: {HttpHeaders.acceptEncodingHeader: "gzip"});
      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);
        List<DateTime> validTime = List.empty(growable: true);
        for (String time in json["validTime"]) {
          DateTime? date = DateTime.tryParse(time);
          if (date != null) validTime.add(date);
        }
        return validTime;
      }
    } catch (e) {
      print(e);
    }
  }

  ///Returns a complete [Forecast] approximately 10 days ahead of the latest current forecast. All times in the answer given in UTC.
  Future<Forecast?> forecast(GeoPoint point) async {
    try {
      http.Response response = await http.get(
          constructSmhiUri(metfcstHost, category, version, [
            "geotype",
            "point",
            "lon",
            point.longitude.toStringAsFixed(6),
            "lat",
            point.latitude.toStringAsFixed(6),
            "data.json",
          ]),
          headers: {HttpHeaders.acceptEncodingHeader: "gzip"});
      if (response.statusCode == 200) {
        return Forecast.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      print(e);
    }
  }

  ///Returns a [MultiPointForecast] which contains a forecast for all grid points with the specified `parameter`, `levelType` and `level`. The parameter `downsample` allows an integer between 0-20. A downsample value of 2 means that every other value horizontally and vertically is displayed.
  Future<MultiPointForecast?> multiPointForecast(DateTime validTime, Parameter parameter, LevelType levelType, int level, {int? downsample}) async {
    DateFormat formatter = DateFormat("yyyyMMdd'T'HHmmss'Z'");
    try {
      http.Response response = await http.get(
          constructSmhiUri(metfcstHost, category, version, [
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
            "with-geo": this._points == null,
            "downsample": downsample != null ? downsample.toString() : "2",
          }),
          headers: {HttpHeaders.acceptEncodingHeader: "gzip"});
      if (response.statusCode == 200) {
        return MultiPointForecast.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      print(e);
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
}

class ForecastMoment {
  late final DateTime validTime;
  late final Map<String, Map<String, dynamic>> _parameters;

  dynamic parameterValue(Parameter parameter, {int? index}) {
    return _parameters[parameter.value]!["values"][index ?? 0];
  }

  String parameterLevelType(Parameter parameter, {int? index}) {
    return _parameters[parameter.value]!["levelType"];
  }

  int parameterLevel(Parameter parameter, {int? index}) {
    return int.parse(_parameters[parameter.value]!["level"]);
  }

  ForecastMoment(
    this.validTime,
    this._parameters,
  );

  factory ForecastMoment.fromJson(json) {
    Map<String, Map<String, dynamic>> params = {};
    for (Map<String, dynamic> param in json["parameters"]) {
      params[param["name"]] = param;
    }
    return ForecastMoment(
      DateTime.parse(json["validTime"]),
      params,
    );
  }
}

///The index for each value in `values` matches the index for the points in  `points`.
class MultiPointForecast {
  late final DateTime approvedTime;
  late final DateTime referenceTime;
  late final List values;
  late final List<GeoPoint>? points;

  MultiPointForecast({
    required this.approvedTime,
    required this.referenceTime,
    required this.values,
    this.points,
  });

  factory MultiPointForecast.fromJson(json) {
    List<GeoPoint>? points;
    if (json["geometry"] != null) {
      points = List.generate(json["geometry"]["coordinates"].length,
          (int index) => GeoPoint(json["geometry"]["coordinates"][index][1], json["geometry"]["coordinates"][index][0]));
    }
    return MultiPointForecast(
      approvedTime: DateTime.parse(json["approvedTime"]),
      referenceTime: DateTime.parse(json["referenceTime"]),
      values: json["timeSeries"][0]["parameters"][0]["values"],
      points: points,
    );
  }
}
