import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'utilities.dart';

const metfcstHost = "opendata-download-metfcst.smhi.se";

/// Meteorological Forecasts
class MetFcst {
  late final Category category;
  late final Version version;

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

  Future<Forecast?> forecast(GeoPoint point) async {
    try {
      http.Response response = await http.get(
          constructSmhiUri(metfcstHost, category, version,
              ["geotype", "point", "lon", point.longitude.toStringAsFixed(6), "lat", point.latitude.toStringAsFixed(6), "data.json"]),
          headers: {HttpHeaders.acceptEncodingHeader: "gzip"});
      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);
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
        point: GeoPoint(json["geometry"]["coordinates"][1], json["geometry"]["coordinates"][0]),
        timeSeries: List.generate(json["timeSeries"].length, (int index) => ForecastMoment.fromJson(json["timeSeries"][index])),
      );
}

class ForecastMoment {
  late final DateTime validTime;
  late final Map<Parameter, Map<String, dynamic>> _parameters;

  dynamic parameterValue(Parameter parameter) {}

  ForecastMoment(
    this.validTime,
    this._parameters,
  );

  factory ForecastMoment.fromJson(json) {
    return ForecastMoment(
      json["validTime"],
      json["parameters"],
    );
  }
}
