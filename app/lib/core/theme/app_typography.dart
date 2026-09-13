import 'package:flutter/material.dart';

class AppTypography {
  static const String fontFamilyBody = 'Inter';
  static const String fontFamilyDisplay = 'Plus Jakarta Sans';

  static const TextStyle displayLg = TextStyle(
    fontFamily: fontFamilyDisplay,
    fontSize: 36,
    height: 44 / 36,
    letterSpacing: -0.02 * 36,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle displayLgMobile = TextStyle(
    fontFamily: fontFamilyDisplay,
    fontSize: 28,
    height: 36 / 28,
    letterSpacing: -0.01 * 28,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle headlineLg = TextStyle(
    fontFamily: fontFamilyDisplay,
    fontSize: 28,
    height: 36 / 28,
    letterSpacing: -0.01 * 28,
    fontWeight: FontWeight.w700,
  );
  
  static const TextStyle headlineLgMobile = TextStyle(
    fontFamily: fontFamilyDisplay,
    fontSize: 22,
    height: 28 / 22,
    letterSpacing: -0.005 * 22,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle headlineMd = TextStyle(
    fontFamily: fontFamilyDisplay,
    fontSize: 20,
    height: 26 / 20,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle headlineSm = TextStyle(
    fontFamily: fontFamilyDisplay,
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle titleLg = TextStyle(
    fontFamily: fontFamilyBody,
    fontSize: 17,
    height: 24 / 17,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle titleMd = TextStyle(
    fontFamily: fontFamilyBody,
    fontSize: 15,
    height: 22 / 15,
    letterSpacing: 0.005 * 15,
    fontWeight: FontWeight.w600,
  );
  
  static const TextStyle currencyDisplay = TextStyle(
    fontFamily: fontFamilyDisplay,
    fontSize: 24,
    height: 30 / 24,
    letterSpacing: -0.01 * 24,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle bodyLg = TextStyle(
    fontFamily: fontFamilyBody,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle bodyMd = TextStyle(
    fontFamily: fontFamilyBody,
    fontSize: 14,
    height: 20 / 14,
    letterSpacing: 0.01 * 14,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle bodySm = TextStyle(
    fontFamily: fontFamilyBody,
    fontSize: 13,
    height: 18 / 13,
    letterSpacing: 0.01 * 13,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle labelLg = TextStyle(
    fontFamily: fontFamilyBody,
    fontSize: 14,
    height: 20 / 14,
    letterSpacing: 0.02 * 14,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle labelMd = TextStyle(
    fontFamily: fontFamilyBody,
    fontSize: 12,
    height: 16 / 12,
    letterSpacing: 0.03 * 12,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle labelSm = TextStyle(
    fontFamily: fontFamilyBody,
    fontSize: 11,
    height: 14 / 11,
    letterSpacing: 0.04 * 11,
    fontWeight: FontWeight.w600,
  );
}
