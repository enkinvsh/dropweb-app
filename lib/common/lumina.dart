import 'dart:ui';
import 'package:flutter/material.dart';

class Lumina {
  Lumina._();

  // Void — NOT pure black, slight blue tint
  static const Color void_ = Color(0xFF030305);

  // Surface hierarchy
  static const Color surface1 = Color(0xFF060608);
  static const Color surface2 = Color(0xFF0A0A0D);
  static const Color surface3 = Color(0xFF0F0F12);
  static const Color surface4 = Color(0xFF141417);
  static const Color surface5 = Color(0xFF1A1A1D);

  // Glass
  static const double glassOpacity = 0.03;
  static const double glassBorderOpacity = 0.08;
  static const double glassHoverOpacity = 0.06;
  static const double glassHoverBorderOpacity = 0.15;

  // Blur — CSS 20px ≈ Flutter sigma 10
  static const double blurSigma = 10.0;
  static const double blurSigmaHeavy = 16.0;

  // Glow colors (adapted for dropweb)
  static const Color glowPrimary = Color(0xFF15803D);
  static const Color glowSecondary = Color(0xFF22C55E);
  static const Color glowAccent = Color(0xFF38BDF8);

  // Shadows
  static const List<BoxShadow> glassShadow = [
    BoxShadow(color: Color(0x33000000), blurRadius: 20, offset: Offset(0, 10)),
  ];
  static const List<BoxShadow> glassDeepShadow = [
    BoxShadow(color: Color(0x4D000000), blurRadius: 30, offset: Offset(0, 15)),
  ];

  // Radii
  static const double radiusMd = 16.0;
  static const double radiusLg = 24.0;
  static const double radiusXl = 32.0;
  static const double radiusXxl = 48.0;

  // Animation
  static const Curve luminaCurve = Cubic(0.2, 0.8, 0.2, 1.0);
  static const Duration luminaDuration = Duration(milliseconds: 400);

  // Glass decoration helper
  static BoxDecoration glass({
    double opacity = glassOpacity,
    double borderOpacity = glassBorderOpacity,
    double radius = radiusXl,
    List<BoxShadow>? shadow,
  }) =>
      BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
            color: Colors.white.withValues(alpha: borderOpacity), width: 1),
        boxShadow: shadow ?? glassShadow,
      );

  // Glass decoration for circles (connect button)
  static BoxDecoration glassCircle({
    double opacity = glassOpacity,
    double borderOpacity = glassBorderOpacity,
    List<BoxShadow>? shadow,
  }) =>
      BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),
        shape: BoxShape.circle,
        border: Border.all(
            color: Colors.white.withValues(alpha: borderOpacity), width: 1),
        boxShadow: shadow ?? glassShadow,
      );

  // Glow shadow for active elements
  static List<BoxShadow> glowShadow(Color color, {double intensity = 0.4}) => [
        BoxShadow(
            color: color.withValues(alpha: intensity),
            blurRadius: 16,
            spreadRadius: 2),
      ];

  // ImageFilter for glass blur
  static ImageFilter get glassBlur =>
      ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma);
  static ImageFilter get heavyBlur =>
      ImageFilter.blur(sigmaX: blurSigmaHeavy, sigmaY: blurSigmaHeavy);
}
