import 'dart:math' as math;

import 'package:balance_detect/core/constants/assessment_config.dart';
import 'package:balance_detect/features/assessment/domain/calibration_record.dart';
import 'package:balance_detect/features/functional_reach/domain/functional_reach_posture_service.dart';
import 'package:balance_detect/features/pose/domain/pose_frame.dart';

/// The published FAB item uses a pencil 10 inches from the outstretched
/// fingertips. The one-foot option is retained as an explicitly labelled
/// experimental variant because it was requested for this application.
enum FullertonProtocolVariant { standardTenInches, oneFoot, legacyUnspecified }

extension FullertonProtocolVariantDetails on FullertonProtocolVariant {
  double get targetDistanceCm => switch (this) {
    FullertonProtocolVariant.standardTenInches => 25.4,
    FullertonProtocolVariant.oneFoot => 30.48,
    FullertonProtocolVariant.legacyUnspecified => throw StateError(
      'Legacy Fullerton results do not have a calibrated target distance',
    ),
  };

  bool get isStandard => this == FullertonProtocolVariant.standardTenInches;
  bool get isExperimental => this == FullertonProtocolVariant.oneFoot;

  String get queryValue => switch (this) {
    FullertonProtocolVariant.standardTenInches => 'standard',
    FullertonProtocolVariant.oneFoot => 'one-foot',
    FullertonProtocolVariant.legacyUnspecified => 'legacy',
  };

  String get thaiLabel => switch (this) {
    FullertonProtocolVariant.standardTenInches =>
      'มาตรฐาน FAB 10 นิ้ว (25.4 ซม.)',
    FullertonProtocolVariant.oneFoot => 'แบบทดลอง 1 ฟุต (30.48 ซม.)',
    FullertonProtocolVariant.legacyUnspecified =>
      'ผลเดิมที่ไม่ระบุระยะเป้าหมาย',
  };

  static FullertonProtocolVariant fromQuery(String? value) =>
      value == FullertonProtocolVariant.oneFoot.queryValue
      ? FullertonProtocolVariant.oneFoot
      : FullertonProtocolVariant.standardTenInches;

  static FullertonProtocolVariant fromStored(String? value) {
    for (final variant in FullertonProtocolVariant.values) {
      if (variant.name == value) return variant;
    }
    return FullertonProtocolVariant.legacyUnspecified;
  }
}

class FullertonReachTarget {
  const FullertonReachTarget({
    required this.startFingertip,
    required this.targetPoint,
    required this.targetDistanceCm,
    required this.protocolVariant,
    required this.imageAspectRatio,
    required this.confidence,
    this.trackedSide,
  });

  final NormalizedPoint startFingertip;
  final NormalizedPoint targetPoint;
  final double targetDistanceCm;
  final FullertonProtocolVariant protocolVariant;
  final double imageAspectRatio;
  final double confidence;
  final PrimaryBodySide? trackedSide;

  bool get isStandardProtocol => protocolVariant.isStandard;

  FullertonReachTarget withTrackedSide(PrimaryBodySide side) =>
      FullertonReachTarget(
        startFingertip: startFingertip,
        targetPoint: targetPoint,
        targetDistanceCm: targetDistanceCm,
        protocolVariant: protocolVariant,
        imageAspectRatio: imageAspectRatio,
        confidence: confidence,
        trackedSide: side,
      );
}

/// Pure image-space geometry for the fixed virtual pencil target.
///
/// [CalibrationRecord.scaleCmPerNormalizedUnit] is the horizontal scale. The
/// vertical scale differs by the image aspect ratio, so both axes are first
/// treated in an isotropic metric space. This keeps the result equivariant to
/// front-camera mirroring and camera roll.
class FullertonTargetGeometry {
  const FullertonTargetGeometry();

  FullertonReachTarget create({
    required NormalizedPoint fingertip,
    required NormalizedPoint shoulder,
    required CalibrationRecord calibration,
    required double imageAspectRatio,
    required FullertonProtocolVariant protocolVariant,
  }) {
    _validateInputs(
      fingertip: fingertip,
      shoulder: shoulder,
      calibration: calibration,
      imageAspectRatio: imageAspectRatio,
    );
    final horizontalScale = calibration.scaleCmPerNormalizedUnit;
    final verticalScale = horizontalScale / imageAspectRatio;
    final armXcm = (fingertip.x - shoulder.x) * horizontalScale;
    final armYcm = (fingertip.y - shoulder.y) * verticalScale;
    final armLengthCm = math.sqrt(armXcm * armXcm + armYcm * armYcm);
    if (armLengthCm < 1) {
      throw const FormatException(
        'แนวแขนสั้นเกินไป กรุณาหันด้านข้างและเหยียดแขนให้เห็นชัด',
      );
    }

    final distanceCm = protocolVariant.targetDistanceCm;
    final targetX =
        fingertip.x + (armXcm / armLengthCm) * distanceCm / horizontalScale;
    final targetY =
        fingertip.y + (armYcm / armLengthCm) * distanceCm / verticalScale;
    final margin = AssessmentConfig.fullertonTargetSafeMarginNormalized;
    if (targetX < margin ||
        targetX > 1 - margin ||
        targetY < margin ||
        targetY > 1 - margin) {
      throw const FormatException(
        'พื้นที่ด้านหน้าไม่พอ กรุณาขยับผู้ทดสอบไปด้านหลังของภาพแล้วคาลิเบรตใหม่',
      );
    }

    return FullertonReachTarget(
      startFingertip: fingertip,
      targetPoint: NormalizedPoint(
        x: targetX,
        y: targetY,
        confidence: math.min(fingertip.confidence, shoulder.confidence),
      ),
      targetDistanceCm: distanceCm,
      protocolVariant: protocolVariant,
      imageAspectRatio: imageAspectRatio,
      confidence:
          math.min(fingertip.confidence, shoulder.confidence) *
          calibration.confidence,
    );
  }

  double metricDistanceCm(
    NormalizedPoint first,
    NormalizedPoint second, {
    required CalibrationRecord calibration,
    required double imageAspectRatio,
  }) {
    if (!imageAspectRatio.isFinite || imageAspectRatio <= 0) {
      throw const FormatException('อัตราส่วนภาพจากกล้องไม่ถูกต้อง');
    }
    final horizontalScale = calibration.scaleCmPerNormalizedUnit;
    if (!horizontalScale.isFinite || horizontalScale <= 0) {
      throw const FormatException('สเกลระยะจากส่วนสูงไม่ถูกต้อง');
    }
    final dx = (second.x - first.x) * horizontalScale;
    final dy = (second.y - first.y) * horizontalScale / imageAspectRatio;
    return math.sqrt(dx * dx + dy * dy);
  }

  void _validateInputs({
    required NormalizedPoint fingertip,
    required NormalizedPoint shoulder,
    required CalibrationRecord calibration,
    required double imageAspectRatio,
  }) {
    if (!fingertip.x.isFinite ||
        !fingertip.y.isFinite ||
        !shoulder.x.isFinite ||
        !shoulder.y.isFinite) {
      throw const FormatException('พิกัดแขนจากกล้องไม่ถูกต้อง');
    }
    if (fingertip.confidence < AssessmentConfig.poseConfidenceThreshold ||
        shoulder.confidence < AssessmentConfig.poseConfidenceThreshold) {
      throw const FormatException('ยังเห็นหัวไหล่หรือปลายนิ้วไม่ชัด');
    }
    if (!imageAspectRatio.isFinite || imageAspectRatio <= 0) {
      throw const FormatException('อัตราส่วนภาพจากกล้องไม่ถูกต้อง');
    }
    if (!calibration.scaleCmPerNormalizedUnit.isFinite ||
        calibration.scaleCmPerNormalizedUnit <= 0) {
      throw const FormatException('สเกลระยะจากส่วนสูงไม่ถูกต้อง');
    }
  }
}

class FullertonArmCalibrationStatus {
  const FullertonArmCalibrationStatus({
    required this.postureReady,
    required this.fingertipVisible,
    required this.acceptedFrameCount,
    required this.canCalibrate,
    required this.guidance,
    required this.armToTorsoAngleDegrees,
    required this.elbowAngleDegrees,
  });

  final bool postureReady;
  final bool fingertipVisible;
  final int acceptedFrameCount;
  final bool canCalibrate;
  final String guidance;
  final double? armToTorsoAngleDegrees;
  final double? elbowAngleDegrees;
}

class FullertonArmCalibrationService {
  FullertonArmCalibrationService([
    this._geometry = const FullertonTargetGeometry(),
  ]);

  final FullertonTargetGeometry _geometry;
  final List<_ArmCalibrationSample> _samples = <_ArmCalibrationSample>[];
  final FunctionalReachPostureService _postureService =
      const FunctionalReachPostureService();
  PrimaryBodySide? _side;
  double? _imageAspectRatio;

  int get acceptedFrameCount => _samples.length;

  FullertonArmCalibrationStatus addFrame(
    PoseFrame frame,
    PrimaryBodySide side,
  ) {
    final posture = _postureService.validate(frame, side);
    final fingertip = frame[side.indexFinger];
    final shoulder = frame[side.shoulder];
    final wrist = frame[side.wrist];
    final fingertipVisible =
        fingertip != null &&
        fingertip.confidence >= AssessmentConfig.poseConfidenceThreshold;
    final shoulderVisible =
        shoulder != null &&
        shoulder.confidence >= AssessmentConfig.poseConfidenceThreshold;
    final fingertipAligned =
        fingertipVisible &&
        shoulderVisible &&
        wrist != null &&
        wrist.confidence >= AssessmentConfig.poseConfidenceThreshold &&
        _fingerExtendsPastWrist(
          shoulder,
          wrist,
          fingertip,
          frame.imageAspectRatio,
        );
    final aspectStable =
        frame.imageAspectRatio.isFinite &&
        frame.imageAspectRatio > 0 &&
        (_imageAspectRatio == null ||
            (frame.imageAspectRatio - _imageAspectRatio!).abs() <= .01);
    final sideStable = _side == null || _side == side;
    final accepted =
        posture.canMeasure &&
        fingertipVisible &&
        fingertipAligned &&
        shoulderVisible &&
        aspectStable &&
        sideStable;

    if (!accepted) {
      reset();
      final guidance = !fingertipVisible
          ? 'เหยียดนิ้วให้เห็นปลายนิ้วข้างที่ยกชัดเจน'
          : !fingertipAligned
          ? 'เหยียดนิ้วไปต่อจากแนวข้อมือและค้างให้ตรง'
          : !aspectStable
          ? 'ห้ามหมุนมือถือระหว่างคาลิเบรต'
          : !sideStable
          ? 'ค้างแขนข้างเดิมที่หันเข้ากล้อง'
          : posture.guidance;
      return FullertonArmCalibrationStatus(
        postureReady: posture.canMeasure,
        fingertipVisible: fingertipVisible,
        acceptedFrameCount: 0,
        canCalibrate: false,
        guidance: guidance,
        armToTorsoAngleDegrees: posture.armToTorsoAngleDegrees,
        elbowAngleDegrees: posture.elbowAngleDegrees,
      );
    }

    _side ??= side;
    _imageAspectRatio ??= frame.imageAspectRatio;
    _samples.add(
      _ArmCalibrationSample(
        shoulder: shoulder,
        fingertip: fingertip,
        confidence: math.min(shoulder.confidence, fingertip.confidence),
      ),
    );
    final ready =
        _samples.length >= AssessmentConfig.fullertonArmCalibrationMinFrames;
    return FullertonArmCalibrationStatus(
      postureReady: true,
      fingertipVisible: true,
      acceptedFrameCount: _samples.length,
      canCalibrate: ready,
      guidance: ready
          ? 'คาลิเบรตปลายนิ้วพร้อมแล้ว'
          : 'ค้างแขนข้างเดียวตั้งฉากกับลำตัวและเหยียดนิ้ว',
      armToTorsoAngleDegrees: posture.armToTorsoAngleDegrees,
      elbowAngleDegrees: posture.elbowAngleDegrees,
    );
  }

  FullertonReachTarget finalize({
    required CalibrationRecord calibration,
    required FullertonProtocolVariant protocolVariant,
  }) {
    final side = _side;
    final aspectRatio = _imageAspectRatio;
    if (_samples.length < AssessmentConfig.fullertonArmCalibrationMinFrames ||
        side == null ||
        aspectRatio == null) {
      throw const FormatException(
        'ยังเก็บท่าแขนและตำแหน่งปลายนิ้วได้ไม่ครบ กรุณาค้างท่าเดิม',
      );
    }
    final fingertips = _samples.map((sample) => sample.fingertip).toList();
    final shoulders = _samples.map((sample) => sample.shoulder).toList();
    final fingertip = _medianPoint(fingertips);
    final shoulder = _medianPoint(shoulders);
    final jitter = _percentile(
      fingertips
          .map(
            (point) => math.sqrt(
              math.pow((point.x - fingertip.x) * aspectRatio, 2) +
                  math.pow(point.y - fingertip.y, 2),
            ),
          )
          .toList(),
      .90,
    );
    if (jitter > AssessmentConfig.fullertonArmMaxFingertipJitterNormalized) {
      throw const FormatException(
        'ปลายนิ้วยังไม่นิ่ง กรุณาค้างแขนและเหยียดนิ่งอีกครั้ง',
      );
    }
    return _geometry
        .create(
          fingertip: fingertip,
          shoulder: shoulder,
          calibration: calibration,
          imageAspectRatio: aspectRatio,
          protocolVariant: protocolVariant,
        )
        .withTrackedSide(side);
  }

  void reset() {
    _samples.clear();
    _side = null;
    _imageAspectRatio = null;
  }

  bool _fingerExtendsPastWrist(
    NormalizedPoint shoulder,
    NormalizedPoint wrist,
    NormalizedPoint fingertip,
    double imageAspectRatio,
  ) {
    if (!imageAspectRatio.isFinite || imageAspectRatio <= 0) return false;
    final armX = (wrist.x - shoulder.x) * imageAspectRatio;
    final armY = wrist.y - shoulder.y;
    final fingerX = (fingertip.x - wrist.x) * imageAspectRatio;
    final fingerY = fingertip.y - wrist.y;
    final fingerLength = math.sqrt(fingerX * fingerX + fingerY * fingerY);
    final dot = armX * fingerX + armY * fingerY;
    return fingerLength >= .005 && dot > 0;
  }

  NormalizedPoint _medianPoint(List<NormalizedPoint> points) => NormalizedPoint(
    x: _median(points.map((point) => point.x).toList()),
    y: _median(points.map((point) => point.y).toList()),
    confidence: _median(points.map((point) => point.confidence).toList()),
  );

  double _median(List<double> values) {
    final sorted = [...values]..sort();
    final middle = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[middle]
        : (sorted[middle - 1] + sorted[middle]) / 2;
  }

  double _percentile(List<double> values, double percentile) {
    final sorted = [...values]..sort();
    final index = ((sorted.length - 1) * percentile).round();
    return sorted[index];
  }
}

class _ArmCalibrationSample {
  const _ArmCalibrationSample({
    required this.shoulder,
    required this.fingertip,
    required this.confidence,
  });

  final NormalizedPoint shoulder;
  final NormalizedPoint fingertip;
  final double confidence;
}
