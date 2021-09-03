import 'dart:convert';
import 'package:http/http.dart' as http;
import 'utilities.dart';

/// Meteorological Forecasts
class MetFcst {
  late final Category category;
  late final Version version;

  Future<DateTime?> get approvedTime async {
    http.Response response = await http.get(constructSmhiUri(category, version, ["approvedtime.json"]));
    if (response.statusCode == 200) {
      try {
        var json = jsonDecode(response.body);
        return DateTime.tryParse(json["referenceTime"]);
      } catch (e) {
        print(e);
      }
    }
  }

  Future<List<DateTime>?> get validTime async {
    http.Response response = await http.get(constructSmhiUri(category, version, ["validtime.json"]));
    if (response.statusCode == 200) {
      try {
        var json = jsonDecode(response.body);
        List<DateTime> validTime = List.empty(growable: true);
        for (String time in json["validTime"]) {
          DateTime? date = DateTime.tryParse(time);
          if (date != null) validTime.add(date);
        }
        return validTime;
      } catch (e) {
        print(e);
      }
    }
  }
}
