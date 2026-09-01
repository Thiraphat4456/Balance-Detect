import 'package:balance_detect/app/balance_detect_app.dart';
import 'package:balance_detect/features/fullerton/presentation/fullerton_intro_screen.dart';
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
    expect(find.text('3 รายการ'), findsOneWidget);
    expect(find.text('วัดระยะเอื้อม'), findsOneWidget);
    expect(find.text('ทดสอบเอื้อมหยิบ'), findsOneWidget);
    expect(find.text('ทดสอบลุก–เดิน–นั่ง'), findsOneWidget);
    expect(find.text('ใช้กล้อง'), findsNWidgets(2));
    expect(find.text('ใช้เซนเซอร์'), findsOneWidget);
    expect(find.text('กล้องหน้า'), findsNWidgets(2));

    await tester.tap(find.text('วัดระยะเอื้อม'));
    await tester.pumpAndSettle();

    expect(find.text('วิธีเตรียมตัว'), findsOneWidget);
    expect(find.text('Functional Reach Test'), findsOneWidget);
    expect(find.text('ส่วนสูงผู้ทดสอบ'), findsOneWidget);
    expect(find.text('กรอกส่วนสูง'), findsOneWidget);
    expect(find.text('ขั้นตอนเตรียมตัว'), findsOneWidget);
    expect(find.text('3 ขั้นตอน'), findsOneWidget);
    expect(find.text('ความปลอดภัย'), findsOneWidget);
    expect(find.text('จัดตำแหน่งกล้อง'), findsOneWidget);
  });

  testWidgets(
    'Fullerton preparation requires height and labels one-foot mode',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: FullertonIntroScreen()));
      await tester.pumpAndSettle();

      expect(
        find.text('Fullerton Advanced Balance Scale — Item 2'),
        findsOneWidget,
      );
      expect(find.text('ส่วนสูงผู้ทดสอบ'), findsOneWidget);
      expect(find.text('ใช้ระยะ 1 ฟุตตามที่กำหนด'), findsOneWidget);
      expect(find.textContaining('Modified FAB'), findsOneWidget);
      expect(find.text('จัดตำแหน่งและคาลิเบรต'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '99');
      await tester.ensureVisible(find.text('จัดตำแหน่งและคาลิเบรต'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('จัดตำแหน่งและคาลิเบรต'));
      await tester.pump();

      expect(
        find.text('กรุณากรอกส่วนสูง 100–230 ซม.'),
        findsOneWidget,
      );
    },
  );
}
