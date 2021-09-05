import 'package:smhi/smhi.dart';

void main() => getTemperatureTomorrow();

///Gets the air temperature at this time tomorrow in Stockholm.
Future<void> getTemperatureTomorrow() async {
  final MeteorologicalForecasts meteorologicalForecasts =
      MeteorologicalForecasts();
  final Forecast? forecast =
      await meteorologicalForecasts.forecast(GeoPoint(59.334591, 18.063240));
  if (forecast != null) {
    //Forecasts are divided into moments where each moment represents a date & time.
    //Read more at SMHI's documentation: https://opendata.smhi.se/apidocs/metfcst/get-forecast.html
    final ForecastMoment moment =
        forecast.momentWhen(DateTime.now().add(const Duration(days: 1)));
    print(moment.valueOf(MetFcstParameter.airTemperature));
  }
}
