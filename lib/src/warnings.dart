// ignore_for_file: avoid_dynamic_calls

import 'package:smhi/src/utilities.dart';

const String _warningsHost = "opendata-download-warnings.smhi.se";

class Warnings {
  late final Version version;

  Warnings({
    this.version = Version.two,
  });

  ///Returns the [District] closest to [at]. Causes an exception if [districts.isEmpty].
  static District districtAt(GeoPoint at, List<District> districts) {
    District? closest;
    double? currentClosestDist;
    for (int i = 0; i < districts.length; i++) {
      if (closest == null) {
        closest = districts[i];
        currentClosestDist = calculateLatLongDistance(
          at.latitude,
          at.longitude,
          closest.point.latitude,
          closest.point.longitude,
        );
      } else {
        final double dist = calculateLatLongDistance(
          at.latitude,
          at.longitude,
          districts[i].point.latitude,
          districts[i].point.longitude,
        );
        if (dist < 100 && dist < currentClosestDist!) {
          closest = districts[i];
          currentClosestDist = dist;
        }
      }
    }
    return closest!;
  }

  ///Returns the [Alert] with the highest [AlertSeverity]. Causes an exception if [alerts.isEmpty].
  static Alert highestSeverity(List<Alert> alerts) {
    Alert? highest;
    for (final Alert alert in alerts) {
      if (highest == null || alert.severity.compareTo(highest.severity) == 1) {
        highest = alert;
      }
    }
    return highest!;
  }

  static AlertSeverity _alertSeverityFromString(String string) {
    switch (string.toLowerCase()) {
      case "extreme":
        return AlertSeverity.extreme;
      case "severe":
        return AlertSeverity.severe;
      case "moderate":
        return AlertSeverity.moderate;
      case "minor":
        return AlertSeverity.minor;
      default:
        return AlertSeverity.unknown;
    }
  }

  static AlertCategory _alertCategoryFromString(String string) {
    switch (string.toLowerCase()) {
      case "warning":
        return AlertCategory.warning;
      case "message":
        return AlertCategory.message;
      case "risk":
        return AlertCategory.risk;
      default:
        return AlertCategory.message;
    }
  }

  static List<String> _stringToList(String string) {
    final List<String> split = string.split(",");
    return List.generate(split.length, (int index) => split[index].trim());
  }

  Future<List<Alert>?> alerts() async {
    final data = await smhiRequest(constructWarningsUri(_warningsHost, version, ["alerts.json"]));
    if (data != null && data["alert"] != null) {
      return List.generate(data["alert"].length, (int index) => Alert.fromJson(data["alert"][index]));
    }
    return null;
  }

  ///Returns one [Message] in a list, for now. SMHI only returns one message object (not an array with one), even though the API seems to indicate that it returns muliple.
  Future<List<Message>?> messages() async {
    final data = await smhiRequest(constructWarningsUri(_warningsHost, version, ["messages.json"]));
    if (data != null && data["message"] != null) {
      return [
        Message.fromJson(data["message"]),
      ];
    }
    return null;
  }

  ///Returns either all districts or a specific type (land and sea).
  Future<List<District>?> districts(DistrictType type) async {
    final data = await smhiRequest(constructWarningsUri(_warningsHost, version, ["districtviews", "${type.value}.json"]));
    if (data != null && data["district_view"] != null) {
      return List.generate(data["district_view"].length, (int index) => District.fromJson(data["district_view"][index]));
    }
    return null;
  }
}

Uri constructWarningsUri(String host, Version version, Iterable<String> api, {Map<String, dynamic>? query}) {
  final List<String> segments = ["api", "version", version.value.toString()];
  segments.addAll(api);
  return Uri(
    host: host,
    scheme: "https",
    pathSegments: segments,
    queryParameters: query,
  );
}

enum DistrictType {
  all,
  land,
  sea,
}

extension DistrictExtension on DistrictType {
  String get value {
    switch (this) {
      case DistrictType.all:
        return "all";
      case DistrictType.land:
        return "land";
      case DistrictType.sea:
        return "sea";
    }
  }
}

enum AlertCategory {
  warning,
  risk,
  message,
}

enum AlertSeverity {
  extreme,
  severe,
  moderate,
  minor,
  unknown,
}

extension AlertSeverityExtension on AlertSeverity {
  int get id {
    switch (this) {
      case AlertSeverity.extreme:
        return 0;
      case AlertSeverity.severe:
        return 1;
      case AlertSeverity.moderate:
        return 2;
      case AlertSeverity.minor:
        return 3;
      case AlertSeverity.unknown:
        return 4;
    }
  }

  ///Returns a negative number if ``this`` is less servere than ``other``, zero if they are equal, and a positive number if ``this`` more servere than ``other``.
  int compareTo(AlertSeverity other) => other.id.compareTo(id);
}

class Alert {
  String id;
  DateTime sent;
  DateTime updated;
  AlertCategory category;
  String descriptionSV;
  String descriptionEN;
  String titleSV;
  String titleEN;
  String headline;
  AlertSeverity severity;
  String web;
  List<String> districts;

  Alert(
    this.id,
    this.sent,
    this.updated,
    this.category,
    this.descriptionSV,
    this.descriptionEN,
    this.titleSV,
    this.titleEN,
    this.headline,
    this.severity,
    this.web,
    this.districts,
  );

  factory Alert.fromJson(alert) => Alert(
        alert["identifier"],
        DateTime.parse(alert["sent"]),
        DateTime.parse(alert["code"][1].split(" ")[1]),
        Warnings._alertCategoryFromString(alert["code"][3].split(" ")[1]),
        alert["info"]["description"],
        alert["info"]["parameter"][1]["value"],
        alert["info"]["eventCode"][3]["value"],
        alert["info"]["eventCode"][0]["value"],
        alert["info"]["headline"],
        Warnings._alertSeverityFromString(alert["info"]["severity"]),
        alert["info"]["web"],
        Warnings._stringToList(alert["info"]["area"]["areaDesc"]),
      );

  @override
  String toString() => titleEN;
}

class District {
  String id;
  int sortOrder;
  DistrictType type;
  String name;
  GeoPoint point;
  String polygon;

  District(
    this.id,
    this.sortOrder,
    this.type,
    this.name,
    this.point,
    this.polygon,
  );

  factory District.fromJson(json) => District(
        json["id"],
        json["sort_order"],
        stringToType(json["category"])!,
        json["name"],
        GeoPoint.fromStringPoint(json["geometry"]["point"]),
        json["geometry"]["polygon"],
      );

  @override
  String toString() => "ID: $id, name: $name";
}

DistrictType? stringToType(String string) {
  switch (string) {
    case "all":
      return DistrictType.all;
    case "land":
      return DistrictType.land;
    case "sea":
      return DistrictType.sea;
  }
  return null;
}

class Message {
  String id;
  String text;
  DateTime timestamp;
  DateTime onset;
  DateTime expires;

  Message(
    this.id,
    this.text,
    this.timestamp,
    this.onset,
    this.expires,
  );

  factory Message.fromJson(message) => Message(
        message["id"],
        message["text"],
        DateTime.parse(message["time_stamp"]),
        DateTime.parse(message["onset"]),
        DateTime.parse(message["expires"]),
      );

  @override
  String toString() => text.length > 40 ? "${"ID: $id, text: ${text.substring(0, 40)}"}..." : "ID: $id, text: $text";
}
