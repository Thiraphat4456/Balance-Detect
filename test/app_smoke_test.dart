import 'package:balance_detect/app/balance_detect_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows Balance Detect splash screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: BalanceDetectApp()));

    expect(find.text('Balance Detect'), findsOneWidget);
    expect(find.text('ประเมินการทรงตัวอย่างเป็นขั้นตอน'), findsOneWidget);
  });

  testWidgets('shows clear assessment choices and preparation flow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(child: BalanceDetectApp()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('เลือกแบบประเมิน'), findsOneWidget);
    expect(find.text('วัดระยะเอื้อม'), findsOneWidget);
    expect(find.text('กล้องหน้า • เห็นร่างกายเต็มตัว'), findsOneWidget);

    await tester.tap(find.text('วัดระยะเอื้อม'));
    await tester.pumpAndSettle();

    expect(find.text('วิธีเตรียมตัว'), findsOneWidget);
    expect(find.text('กรอกส่วนสูงก่อนเริ่ม'), findsOneWidget);
    expect(find.text('ส่วนสูงผู้ทดสอบ'), findsOneWidget);
    expect(find.text('เตรียมให้พร้อม'), findsOneWidget);
    expect(find.text('กรอกส่วนสูงแล้วจัดตำแหน่งกล้อง'), findsOneWidget);
  });
}
