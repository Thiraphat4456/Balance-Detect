import 'package:balance_detect/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class ReachThresholdBar extends StatelessWidget {
  const ReachThresholdBar({required this.distanceInches, super.key});

  final double distanceInches;

  @override
  Widget build(BuildContext context) {
    final marker = (distanceInches / 14).clamp(0.0, 1.0);
    const threshold = 0.5;
    return Semantics(
      label:
          'ระยะ ${distanceInches.toStringAsFixed(1)} นิ้ว เทียบกับเกณฑ์ 7 นิ้ว',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 54,
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: 20,
                    left: 0,
                    right: 0,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: const Row(
                        children: [
                          Expanded(
                            child: ColoredBox(
                              color: AppColors.warningContainer,
                              child: SizedBox(height: 16),
                            ),
                          ),
                          Expanded(
                            child: ColoredBox(
                              color: AppColors.normalContainer,
                              child: SizedBox(height: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 13,
                    left: constraints.maxWidth * threshold - 1,
                    child: Container(
                      width: 2,
                      height: 30,
                      color: Colors.black54,
                    ),
                  ),
                  Positioned(
                    top: 9,
                    left: (constraints.maxWidth * marker - 10).clamp(
                      0.0,
                      constraints.maxWidth - 20,
                    ),
                    child: const Icon(
                      Icons.arrow_drop_down_circle,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text('0 นิ้ว'), Text('เกณฑ์ 7 นิ้ว'), Text('14+ นิ้ว')],
          ),
        ],
      ),
    );
  }
}
