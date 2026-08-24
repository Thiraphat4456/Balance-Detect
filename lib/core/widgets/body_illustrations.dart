import 'package:balance_detect/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class SideReachIllustration extends StatelessWidget {
  const SideReachIllustration({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'ภาพคนยืนด้านข้าง ยกแขนและเอื้อมไปข้างหน้า',
    child: Container(
      width: 260,
      height: 210,
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(24),
      ),
      child: CustomPaint(painter: _SideReachPainter()),
    ),
  );
}

class WaistPhoneIllustration extends StatelessWidget {
  const WaistPhoneIllustration({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'ภาพโทรศัพท์ติดแน่นบริเวณเอว',
    child: Container(
      width: 260,
      height: 210,
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(24),
      ),
      child: CustomPaint(painter: _WaistPhonePainter()),
    ),
  );
}

class _SideReachPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final body = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final guide = Paint()
      ..color = AppColors.warning
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(size.width * .38, 42), 18, body);
    canvas.drawLine(
      Offset(size.width * .38, 62),
      Offset(size.width * .42, 125),
      body,
    );
    canvas.drawLine(
      Offset(size.width * .40, 78),
      Offset(size.width * .77, 82),
      body,
    );
    canvas.drawLine(
      Offset(size.width * .42, 125),
      Offset(size.width * .31, 184),
      body,
    );
    canvas.drawLine(
      Offset(size.width * .42, 125),
      Offset(size.width * .53, 184),
      body,
    );
    canvas.drawLine(
      Offset(size.width * .18, 194),
      Offset(size.width * .68, 194),
      guide,
    );
    canvas.drawLine(
      Offset(size.width * .55, 66),
      Offset(size.width * .83, 66),
      guide,
    );
    canvas.drawLine(
      Offset(size.width * .80, 61),
      Offset(size.width * .85, 66),
      guide,
    );
    canvas.drawLine(
      Offset(size.width * .80, 71),
      Offset(size.width * .85, 66),
      guide,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WaistPhonePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final body = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final phone = Paint()
      ..color = AppColors.warning
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(size.width * .50, 35), 17, body);
    canvas.drawLine(
      Offset(size.width * .50, 54),
      Offset(size.width * .50, 126),
      body,
    );
    canvas.drawLine(
      Offset(size.width * .50, 72),
      Offset(size.width * .31, 112),
      body,
    );
    canvas.drawLine(
      Offset(size.width * .50, 72),
      Offset(size.width * .69, 112),
      body,
    );
    canvas.drawLine(
      Offset(size.width * .50, 126),
      Offset(size.width * .35, 184),
      body,
    );
    canvas.drawLine(
      Offset(size.width * .50, 126),
      Offset(size.width * .65, 184),
      body,
    );
    final phoneRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width * .50, 112),
        width: 34,
        height: 48,
      ),
      const Radius.circular(6),
    );
    canvas.drawRRect(phoneRect, phone);
    canvas.drawLine(
      Offset(size.width * .28, 112),
      Offset(size.width * .72, 112),
      phone,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
