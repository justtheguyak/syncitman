import 'package:flutter/material.dart';

class AppColors {
  // Primary couple theme colors
  static const Color primary = Color(0xFFE91E63); // Romantic Rose Pink
  static const Color primaryDark = Color(0xFFC2185B);
  static const Color primaryLight = Color(0xFFF8BBD0);
  
  static const Color secondary = Color(0xFFFF6F61); // Coral Heart
  static const Color accent = Color(0xFF8E24AA); // Royal Violet
  static const Color partnerAccent = Color(0xFF4A90E2); // Calm Sky Blue for partner

  // Light Theme Surfaces
  static const Color lightBackground = Color(0xFFFDF8F9);
  static const Color lightCard = Colors.white;
  static const Color lightTextPrimary = Color(0xFF1E212D);
  static const Color lightTextSecondary = Color(0xFF6B7280);
  static const Color lightBorder = Color(0xFFF1D8E1);

  // Dark Theme Surfaces
  static const Color darkBackground = Color(0xFF121214);
  static const Color darkCard = Color(0xFF1E1E24);
  static const Color darkCardElevated = Color(0xFF26262E);
  static const Color darkTextPrimary = Color(0xFFF3F4F6);
  static const Color darkTextSecondary = Color(0xFF9CA3AF);
  static const Color darkBorder = Color(0xFF2D2D38);

  // Priority Colors
  static const Color priorityLow = Color(0xFF10B981); // Emerald Green
  static const Color priorityMedium = Color(0xFFF59E0B); // Amber / Gold
  static const Color priorityHigh = Color(0xFFEF4444); // Crimson Red

  // Status Colors
  static const Color statusPending = Color(0xFFF59E0B);
  static const Color statusInProgress = Color(0xFF3B82F6);
  static const Color statusDone = Color(0xFF10B981);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFE91E63), Color(0xFFFF6F61)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    colors: [Color(0xFF23232C), Color(0xFF1A1A20)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
