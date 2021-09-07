[![Pub](https://img.shields.io/pub/v/smhi.svg)](https://pub.dartlang.org/packages/smhi) 
[![style: lint](https://img.shields.io/badge/style-lint-4BC0F5.svg)](https://pub.dev/packages/lint)

# SMHI Open Data for Dart
*This package is in early development and some features may not work as intended. If so, feel free to [submit a pull request][pullRequest].*

A Dart package for usage of the [Swedish Meteorological and Hydrological Institute's Open Data API][smhiDocs].
The API allows you to get the weather and other meterological data like air temperature & pressure.
At the time of writing this, the Meteorological Forecasts API is available in the following countries:
- Sweden
- Norway
- Finland
- Denmark
- Estonia

And partly:
- Latvia
- Lithuania

## Usage

This example shows how to get the air temperature at this time tomorrow in Stockholm:
```dart
import 'package:smhi/smhi.dart';

final MeteorologicalForecasts meteorologicalForecasts = MeteorologicalForecasts();
// Your request will automatically be cached. So if you make the same one again, it will return the cached version.
final Forecast? forecast = await meteorologicalForecasts.forecast(GeoPoint(59.334591, 18.063240));
if (forecast != null) {
	// Forecasts are divided into moments where each moment represents a date & time.
	// Read more at SMHI's documentation: https://opendata.smhi.se/apidocs/metfcst/get-forecast.html
	final ForecastMoment moment = forecast.momentWhen(DateTime.now().add(const Duration(days: 1)));
	print(moment.valueOf(MetFcstParameter.airTemperature));
}
```

## Supported SMHI Open Data APIs

| API                      | Supported          |
|--------------------------|--------------------|
| Meteorological Forecasts | ✅ (Only pmp3gv2) |

## Terms of use

You can find [SMHI's terms of use][smhiTerms] and their [documentation][smhiDocs] on their website, written in Swedish and English respectively. Their open data follows the [Creative Commons Attribution 4.0 International (CC BY 4.0)][ccLicense] license.

To prevent high unnecessary usage of SMHI's API, requests will automatically be cached.
You can clear the cache manually:
```dart
SMHICache().clear();
```

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/Lucke0051/smhi/issues
[pullRequest]: https://github.com/Lucke0051/smhi/pulls
[smhiDocs]: https://opendata.smhi.se/apidocs/metfcst/index.html
[smhiTerms]: https://www.smhi.se/data/oppna-data/information-om-oppna-data/villkor-for-anvandning-1.30622
[ccLicense]: https://creativecommons.org/licenses/by/4.0/deed