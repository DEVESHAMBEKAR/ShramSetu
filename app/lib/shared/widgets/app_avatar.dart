import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class AppAvatar extends StatelessWidget {
  final String imageUrl;
  final double radius;
  final String? placeholderName;

  const AppAvatar({
    super.key,
    required this.imageUrl,
    this.radius = 24.0,
    this.placeholderName,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.surfaceVariant,
      backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
      child: imageUrl.isEmpty && placeholderName != null
          ? Text(
              placeholderName![0].toUpperCase(),
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            )
          : null,
    );
  }
}
