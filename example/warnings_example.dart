// ignore_for_file: avoid_print

import 'package:smhi/smhi.dart';

void main() => getWarnings();

///Gets the alert with the highest severity.
Future<void> getWarnings() async {
  final Warnings warnings = Warnings();
  final List<Alert>? alerts = await warnings.alerts();
  if (alerts != null) {
    print(Warnings.highestSeverity(alerts).severity);
  }
}
