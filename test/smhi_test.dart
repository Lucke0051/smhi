import 'package:smhi/smhi.dart';
import 'package:test/test.dart';

void main() {
  test("Make sure latitude & longitude distance is measured correctly", () {
    expect(calculateLatLongDistance(59.29607685996352, 18.01752615981483, 37.334626552421454, -122.0093063155558), equals(8657.453523594228));
  });
}