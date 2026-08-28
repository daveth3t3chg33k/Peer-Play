import 'package:flutter/material.dart';
import '../config/theme.dart';

class LoadingSpinner extends StatelessWidget {
  final String? message;

  const LoadingSpinner({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            color: AppTheme.primary,
            strokeWidth: 3,
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }
}
