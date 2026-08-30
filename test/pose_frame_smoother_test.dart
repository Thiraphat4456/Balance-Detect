import 'package:balance_detect/features/pose/domain/pose_frame.dart';
import 'package:balance_detect/features/pose/domain/pose_frame_smoother.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('damps a small stationary landmark jitter', () {
    final smoother = PoseFrameSmoother();
    smoother.smooth(_frame(x: .50, y: .40, timestampMs: 0));

    final result = smoother.smooth(_frame(x: .54, y: .44, timestampMs: 100));

    expect(result[BodyLandmark.leftWrist]!.x, greaterThan(.50));
    expect(result[BodyLandmark.leftWrist]!.x, lessThan(.54));
    expect(result[BodyLandmark.leftWrist]!.y, greaterThan(.40));
    expect(result[BodyLandmark.leftWrist]!.y, lessThan(.44));
    expect(result[BodyLandmark.leftWrist]!.confidence, .95);
  });

  test('follows a large movement immediately', () {
    final smoother = PoseFrameSmoother();
    smoother.smooth(_frame(x: .20, y: .40, timestampMs: 0));

    final result = smoother.smooth(_frame(x: .55, y: .42, timestampMs: 100));

    expect(result[BodyLandmark.leftWrist]!.x, .55);
    expect(result[BodyLandmark.leftWrist]!.y, .42);
  });

  test('does not carry a stale pose across a missing frame', () {
    final smoother = PoseFrameSmoother();
    smoother.smooth(_frame(x: .20, y: .40, timestampMs: 0));
    smoother.smooth(
      const PoseFrame(
        timestamp: Duration(milliseconds: 100),
        landmarks: {},
        imageAspectRatio: 2 / 3,
      ),
    );

    final result = smoother.smooth(_frame(x: .80, y: .40, timestampMs: 200));

    expect(result[BodyLandmark.leftWrist]!.x, .80);
  });
}

PoseFrame _frame({
  required double x,
  required double y,
  required int timestampMs,
}) => PoseFrame(
  timestamp: Duration(milliseconds: timestampMs),
  imageAspectRatio: 2 / 3,
  landmarks: <BodyLandmark, NormalizedPoint>{
    BodyLandmark.leftWrist: NormalizedPoint(
      x: x,
      y: y,
      confidence: .95,
    ),
  },
);
