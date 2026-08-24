import 'package:balance_detect/core/constants/assessment_config.dart';
import 'package:balance_detect/core/domain/assessment_enums.dart';
import 'package:balance_detect/core/utils/id_generator.dart';
import 'package:balance_detect/features/assessment/domain/calibration_record.dart';
import 'package:balance_detect/features/pose/domain/pose_frame.dart';

abstract interface class DistanceCalibrationService {
  CalibrationRecord calibrate({
    required String sessionId,
    required NormalizedPoint firstPoint,
    required NormalizedPoint secondPoint,
    required double referenceDistanceCm,
  });

  double normalizedDistanceToCentimeters(
    double normalizedDistance,
    CalibrationRecord calibration,
  );
}

class ExplicitDistanceCalibrationService implements DistanceCalibrationService {
  const ExplicitDistanceCalibrationService();

  @override
  CalibrationRecord calibrate({
    required String sessionId,
    required NormalizedPoint firstPoint,
    required NormalizedPoint secondPoint,
    required double referenceDistanceCm,
  }) {
    if (referenceDistanceCm < AssessmentConfig.calibrationMinReferenceCm ||
        referenceDistanceCm > AssessmentConfig.calibrationMaxReferenceCm) {
      throw const FormatException('ระยะอ้างอิงอยู่นอกช่วงที่รองรับ');
    }
    final normalizedSpan = (firstPoint.x - secondPoint.x).abs();
    if (normalizedSpan < AssessmentConfig.calibrationMinNormalizedSpan) {
      throw const FormatException('จุดอ้างอิงตามแนวนอนอยู่ใกล้กันเกินไป');
    }
    if ((firstPoint.y - secondPoint.y).abs() >
        AssessmentConfig.calibrationMaxVerticalDrift) {
      throw const FormatException(
        'กรุณาวางวัตถุอ้างอิงตามแนวนอนให้ขนานกับทิศทางการเอื้อม',
      );
    }
    final confidence = (normalizedSpan / 0.35).clamp(0.45, 1.0);
    return CalibrationRecord(
      id: IdGenerator.generate('cal'),
      sessionId: sessionId,
      timestamp: DateTime.now(),
      scaleCmPerNormalizedUnit: referenceDistanceCm / normalizedSpan,
      method: CalibrationMethod.explicitKnownReference,
      referenceDistanceCm: referenceDistanceCm,
      confidence: confidence,
    );
  }

  @override
  double normalizedDistanceToCentimeters(
    double normalizedDistance,
    CalibrationRecord calibration,
  ) => normalizedDistance * calibration.scaleCmPerNormalizedUnit;
}

/// Estimates a metric image scale from a user's entered stature.
///
/// This is an anthropometric prior, not a direct measurement: the pose model
/// currently exposes shoulder and ankle landmarks, so the visible span is
/// converted to an estimated full-body span using a documented configuration
/// constant. The caller must collect multiple stable frames before invoking
/// this service and should keep the explicit-reference method available as a
/// higher-confidence fallback.
class AnthropometricHeightCalibrationService {
  const AnthropometricHeightCalibrationService();

  CalibrationRecord calibrate({
    required String sessionId,
    required double heightCm,
    required List<double> visibleSpanSamples,
    required double imageAspectRatio,
  }) {
    if (heightCm < AssessmentConfig.anthropometricMinHeightCm ||
        heightCm > AssessmentConfig.anthropometricMaxHeightCm) {
      throw const FormatException('ส่วนสูงอยู่นอกช่วงที่รองรับ');
    }
    if (visibleSpanSamples.length <
        AssessmentConfig.anthropometricCalibrationMinFrames) {
      throw const FormatException('ยังเก็บข้อมูลท่าทางไม่พอ กรุณาอยู่นิ่ง');
    }
    if (!imageAspectRatio.isFinite || imageAspectRatio <= 0) {
      throw const FormatException('ไม่สามารถอ่านอัตราส่วนภาพจากกล้องได้');
    }
    final validSamples = visibleSpanSamples
        .where((span) => span > AssessmentConfig.calibrationMinNormalizedSpan)
        .toList(growable: false);
    if (validSamples.length <
        AssessmentConfig.anthropometricCalibrationMinFrames) {
      throw const FormatException(
        'มองเห็นร่างกายไม่ครบพอสำหรับคำนวณสเกลจากส่วนสูง',
      );
    }
    final sorted = [...validSamples]..sort();
    final median = sorted[sorted.length ~/ 2];
    final spanJitter = sorted.last - sorted.first;
    if (spanJitter > AssessmentConfig.anthropometricMaxSpanJitter) {
      throw const FormatException('กรุณาอยู่นิ่งเพื่อคำนวณสเกลจากส่วนสูง');
    }

    final estimatedVisibleHeightCm =
        heightCm * AssessmentConfig.anthropometricVisibleHeightFraction;
    final confidence =
        (1 - spanJitter / AssessmentConfig.anthropometricMaxSpanJitter).clamp(
          AssessmentConfig.calibrationMinConfidence,
          1.0,
        );
    return CalibrationRecord(
      id: IdGenerator.generate('cal'),
      sessionId: sessionId,
      timestamp: DateTime.now(),
      // The body prior is measured on normalized Y, while reach is measured
      // on normalized X. Because X and Y were divided by different image
      // dimensions, width / height converts the vertical scale to horizontal.
      scaleCmPerNormalizedUnit:
          estimatedVisibleHeightCm * imageAspectRatio / median,
      method: CalibrationMethod.anthropometricBodyHeight,
      referenceDistanceCm: heightCm,
      confidence: confidence,
    );
  }
}
