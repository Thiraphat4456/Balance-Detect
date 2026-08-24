import 'package:balance_detect/core/domain/assessment_enums.dart';
import 'package:balance_detect/core/utils/unit_conversion.dart';
import 'package:balance_detect/features/functional_reach/domain/functional_reach_logic.dart';
import 'package:balance_detect/features/tug/domain/tug_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('unit conversion', () {
    test('centimeters to inches', () {
      expect(UnitConversion.centimetersToInches(2.54), closeTo(1, 1e-10));
      expect(UnitConversion.centimetersToInches(17.78), closeTo(7, 1e-10));
    });

    test('inches to centimeters', () {
      expect(UnitConversion.inchesToCentimeters(1), closeTo(2.54, 1e-10));
      expect(UnitConversion.inchesToCentimeters(7), closeTo(17.78, 1e-10));
    });
  });

  group('Functional Reach classification', () {
    test('6.99 inches is warning', () {
      expect(
        FunctionalReachClassifier.classifyInches(6.99),
        AssessmentStatus.warning,
      );
    });

    test('7.00 and 8.00 inches are normal', () {
      expect(
        FunctionalReachClassifier.classifyInches(7),
        AssessmentStatus.normal,
      );
      expect(
        FunctionalReachClassifier.classifyInches(8),
        AssessmentStatus.normal,
      );
    });
  });

  group('TUG risk classification', () {
    test('13.4 and 13.5 seconds are normal', () {
      expect(TugRiskClassifier.classifySeconds(13.4), AssessmentStatus.normal);
      expect(TugRiskClassifier.classifySeconds(13.5), AssessmentStatus.normal);
    });

    test('13.6 and 20.0 seconds are risk', () {
      expect(TugRiskClassifier.classifySeconds(13.6), AssessmentStatus.risk);
      expect(TugRiskClassifier.classifySeconds(20), AssessmentStatus.risk);
    });
  });
}
