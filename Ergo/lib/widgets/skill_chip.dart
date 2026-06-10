import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Skill tag chip with optional "×" remove button.
/// Used in Profile screen and Edit Profile screen.
class SkillChip extends StatelessWidget {
  final String label;
  final VoidCallback? onRemove;

  const SkillChip({
    super.key,
    required this.label,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.primary,
            ),
          ),
          if (onRemove != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(
                Icons.close_rounded,
                size: 14,
                color: AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
