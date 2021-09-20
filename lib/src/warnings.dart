import 'package:smhi/src/utilities.dart';

class Warnings {
  late final Version version;

  Warnings({
    this.version = Version.two,
  });

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

  List<Alert> alerts() {
    List<Alert> alerts = List.empty(growable: true);
  }

  List<Message> messages() {
    List<Alert> alerts = List.empty(growable: true);
  }

  List<District> districts(DistrictType type) {
    List<Alert> alerts = List.empty(growable: true);
  }
}

enum DistrictType {
  all,
  land,
  sea,
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
  AlertSeverity severity;
  String web;
  List<String> districts;
  int color;

  Alert(
    this.id,
    this.sent,
    this.updated,
    this.category,
    this.descriptionSV,
    this.descriptionEN,
    this.titleSV,
    this.titleEN,
    this.severity,
    this.web,
    this.districts,
    this.color,
  );
}

class District {
  String id;
  String sortOrder;
  DistrictType type;
  String name;
  dynamic geometry;

  District(
    this.id,
    this.sortOrder,
    this.type,
    this.name,
    this.geometry,
  );
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
}
