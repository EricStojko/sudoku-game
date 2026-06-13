import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Design tokens — single source of truth for all app colours.
// ---------------------------------------------------------------------------
class AppColors {
  AppColors._(); // prevent instantiation

  static const Color primaryPastel = Color(0xFFC4B5FD); // Soft purple
  static const Color secondaryPastel = Color(0xFFA7F3D0); // Soft mint green
  static const Color accentPastel = Color(0xFFFBCFE8); // Soft pink
  static const Color errorPastel = Color(0xFFFDA4AF); // Soft red
  static const Color fixedCellBg = Color(0xFFF3F4F6); // Soft gray
  static const Color primaryDark = Color(0xFF6D28D9); // Deep purple for text
}
