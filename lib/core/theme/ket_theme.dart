import 'package:flutter/foundation.dart';
import 'package:fluent_ui/fluent_ui.dart';
import '../services/settings_service.dart';

class KetTheme {
  static bool get isDark => SettingsService().themeMode == ThemeMode.dark;
  static bool get isWindowsDesktop =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  static Color get bgCanvas =>
      isDark ? const Color(0xFF101317) : const Color(0xFFF5F6F8);

  static Color get bgSidebar =>
      isDark ? const Color(0xFF171B20) : const Color(0xFFFFFFFF);

  static Color get bgActivityBar =>
      isDark ? const Color(0xFF151A20) : const Color(0xFFF0F2F5);

  static Color get bgHeader =>
      isDark ? const Color(0xFF1A2027) : const Color(0xFFF7F8FA);

  static Color get bgHover =>
      isDark ? const Color(0xFF232A33) : const Color(0xFFECEFF3);

  static Color get bgSelected =>
      isDark ? const Color(0xFF24303B) : const Color(0xFFDCE5F0);

  static Color get bgElevated =>
      isDark ? const Color(0xFF14191E) : const Color(0xFFFFFFFF);

  static Color get bgOverlay =>
      isDark ? const Color(0xF0111820) : const Color(0xF7FFFFFF);

  static Color get border =>
      isDark ? const Color(0xFF2B333C) : const Color(0xFFD7DCE3);

  static Color get borderStrong =>
      isDark ? const Color(0xFF394450) : const Color(0xFFC4CCD6);

  static Color get textMain =>
      isDark ? const Color(0xFFF2F6FB) : const Color(0xFF122033);

  static Color get textSecondary =>
      isDark ? const Color(0xFFB7C4D3) : const Color(0xFF4E627A);

  static Color get textMuted =>
      isDark ? const Color(0xFF8693A3) : const Color(0xFF6A7686);

  static Color get accent => SettingsService().accentColor;
  static Color get accentSoft => accent.withValues(alpha: isDark ? 0.18 : 0.12);
  static Color get success => const Color(0xFF2ACF8B);
  static Color get warning => const Color(0xFFFFB547);
  static Color get danger => const Color(0xFFFF6B7A);

  static List<Color> get canvasGradient => isDark
      ? [
          const Color(0xFF101317),
          const Color(0xFF101317),
          accent.withValues(alpha: 0.015),
        ]
      : [
          const Color(0xFFF5F6F8),
          const Color(0xFFF5F6F8),
          accent.withValues(alpha: 0.015),
        ];

  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.03),
      blurRadius: isDark ? 10 : 8,
      offset: const Offset(0, 2),
      spreadRadius: isDark ? -4 : -4,
    ),
  ];

  static BorderRadius get radiusMd => BorderRadius.circular(6);
  static BorderRadius get radiusLg => BorderRadius.circular(8);

  static TextStyle get globalFont =>
      TextStyle(fontFamily: isWindowsDesktop ? 'Segoe UI' : null);

  static TextStyle get menuStyle => TextStyle(
    fontFamily: isWindowsDesktop ? 'Segoe UI' : null,
    fontSize: 12,
    color: textSecondary,
    fontWeight: FontWeight.w500,
  );

  static TextStyle get headerStyle => TextStyle(
    fontFamily: isWindowsDesktop ? 'Segoe UI Semibold' : null,
    fontSize: 11,
    color: textSecondary,
    letterSpacing: 0.2,
    fontWeight: FontWeight.w600,
  );

  static TextStyle get bodyStyle => TextStyle(
    fontFamily: isWindowsDesktop ? 'Segoe UI' : null,
    fontSize: 13,
    color: textMain,
    fontWeight: FontWeight.w500,
  );

  static TextStyle get descriptionStyle => TextStyle(
    fontFamily: isWindowsDesktop ? 'Segoe UI' : null,
    fontSize: 12,
    color: textMuted,
    height: 1.35,
  );

  static TextStyle get statusStyle => TextStyle(
    fontFamily: isWindowsDesktop ? 'Cascadia Mono' : null,
    fontSize: 10.5,
    color: textMain,
    fontWeight: FontWeight.w600,
  );

  static const EdgeInsets panelPadding = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 10,
  );

  static Decoration get sidebarDecoration => BoxDecoration(
    color: bgSidebar,
    border: Border(right: BorderSide(color: border, width: 1)),
  );

  static BoxDecoration panelSurface({
    bool elevated = false,
    bool selected = false,
    BorderRadius? radius,
  }) {
    return BoxDecoration(
      color: selected ? bgSelected : (elevated ? bgElevated : bgSidebar),
      borderRadius: radius ?? radiusMd,
      border: Border.all(
        color: selected ? accent.withValues(alpha: 0.35) : border,
      ),
      boxShadow: elevated ? softShadow : null,
    );
  }

  static BoxDecoration glassSurface({BorderRadius? radius}) {
    return BoxDecoration(
      color: bgOverlay,
      borderRadius: radius ?? radiusLg,
      border: Border.all(color: border.withValues(alpha: 0.9)),
      boxShadow: softShadow,
    );
  }
}
