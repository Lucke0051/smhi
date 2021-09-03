import 'package:smhi/smhi.dart';
import 'package:intl/intl.dart';

void main() {
  run();
}

void run() async {
  final MeteorologicalForecasts met = MeteorologicalForecasts(category: Category.pmp3g, version: Version.two);
  MultiPointForecast? a = await met.multiPointForecast((await met.approvedTime)!.add(Duration(hours: 1)), Parameter.airTemperature, LevelType.hl, 2);
  print(a);
}
