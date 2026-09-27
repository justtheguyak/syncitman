import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class PriorityBadge extends StatelessWidget {
  final String priority;

  const PriorityBadge({super.key, required this.priority});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    IconData icon;

    switch (priority.toLowerCase()) {
      case 'high':
        color = AppColors.priorityHigh;
        label = 'High';
        icon = Icons.priority_high_rounded;
        break;
      case 'low':
        color = AppColors.priorityLow;
        label = 'Low';
        icon = Icons.low_priority_rounded;
        break;
      case 'medium':
      default:
        color = AppColors.priorityMedium;
        label = 'Medium';
        icon = Icons.remove_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
