import 'package:flutter/material.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 18),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
