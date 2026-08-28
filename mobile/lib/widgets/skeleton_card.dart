import 'package:flutter/material.dart';
import '../config/theme.dart';

class SkeletonCard extends StatelessWidget {
  final double width;
  final double height;

  const SkeletonCard({super.key, this.width = 130, this.height = 195});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusPoster),
      ),
    );
  }
}
