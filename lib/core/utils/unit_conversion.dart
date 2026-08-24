abstract final class UnitConversion {
  static const centimetersPerInch = 2.54;

  static double centimetersToInches(double centimeters) =>
      centimeters / centimetersPerInch;

  static double inchesToCentimeters(double inches) =>
      inches * centimetersPerInch;
}
