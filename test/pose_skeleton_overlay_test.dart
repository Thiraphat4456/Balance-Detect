import 'package:balance_detect/features/pose/domain/pose_frame.dart';
import 'package:balance_detect/features/pose/presentation/pose_skeleton_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders pose skeleton for available landmarks', (tester) async {
    final frame = PoseFrame(
      timestamp: Duration.zero,
      landmarks: const {
        BodyLandmark.leftShoulder: NormalizedPoint(
          x: .4,
          y: .25,
          confidence: .95,
        ),
        BodyLandmark.leftElbow: NormalizedPoint(x: .3, y: .35, confidence: .95),
        BodyLandmark.leftWrist: NormalizedPoint(x: .2, y: .35, confidence: .95),
        BodyLandmark.leftHip: NormalizedPoint(x: .43, y: .55, confidence: .95),
        BodyLandmark.leftKnee: NormalizedPoint(x: .44, y: .72, confidence: .4),
        BodyLandmark.leftAnkle: NormalizedPoint(x: .45, y: .9, confidence: .95),
      },
      imageAspectRatio: .75,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 240,
            height: 420,
            child: PoseSkeletonOverlay(
              frame: frame,
              highlightedSide: PrimaryBodySide.left,
            ),
          ),
        ),
      ),
    );

    final customPaint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(PoseSkeletonOverlay),
        matching: find.byType(CustomPaint),
      ),
    );
    expect(customPaint.painter, isA<PoseSkeletonPainter>());
    expect(tester.takeException(), isNull);
  });

  test('repaints when the tracked side changes', () {
    const frame = PoseFrame(timestamp: Duration.zero, landmarks: {});
    const left = PoseSkeletonPainter(
      frame: frame,
      highlightedSide: PrimaryBodySide.left,
    );
    const right = PoseSkeletonPainter(
      frame: frame,
      highlightedSide: PrimaryBodySide.right,
    );

    expect(right.shouldRepaint(left), isTrue);
  });
}
