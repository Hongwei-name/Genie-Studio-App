import 'package:flutter/material.dart';

/// macOS 风格主题
///
/// 设计规范：
/// - 圆角：主 8px，按钮/卡片 8px，小标签 4px（统一 macOS 标准）
/// - 字体：SF Pro Display → SF Pro Text → PingFang SC → Segoe UI
/// - 间距：4/8/12/16/24/32（8 倍数体系）
/// - 配色：低饱和、柔和、macOS Sonoma 风格
class AppTheme {
  AppTheme._();

  // ─── 强调色（macOS Sonoma 系统色，柔和） ───
  /// 系统蓝
  static const Color primary = Color(0xFF0A84FF);
  static const Color primaryHover = Color(0xFF0066CC);

  /// 成功绿（柔和）
  static const Color success = Color(0xFF30D158);

  /// 危险红（柔和）
  static const Color danger = Color(0xFFFF453A);

  /// 警告橙（柔和）
  static const Color warning = Color(0xFFFF9F0A);

  // ─── 背景色 ───
  /// 侧边栏背景（macOS 毛玻璃灰，纯色模拟）
  static const Color sidebarBackground = Color(0xFFEBEBEE);

  /// 侧边栏选中项背景（macOS 标准蓝底）
  static const Color sidebarSelection = Color(0xFF0A84FF);

  /// 选中项上的文字/图标色
  static const Color textOnSelection = Color(0xFFFFFFFF);

  /// 内容区背景（macOS 窗口背景）
  static const Color windowBackground = Color(0xFFF5F5F7);

  /// 卡片/面板背景（白）
  static const Color surface = Color(0xFFFFFFFF);

  /// 悬浮背景
  static const Color surfaceHover = Color(0xFFF0F0F2);

  /// 选中项半透明背景（列表行）
  static const Color selectionHighlight = Color(0x1A0A84FF);

  // ─── 文本色 ───
  /// 主文本
  static const Color textPrimary = Color(0xFF1D1D1F);

  /// 次要文本
  static const Color textSecondary = Color(0xFF515154);

  /// 辅助文本
  static const Color textTertiary = Color(0xFF86868B);

  /// 选中项文本
  static const Color textSelected = Color(0xFF0A84FF);

  // ─── 分隔线 ───
  static const Color separator = Color(0xFFD2D2D7);
  static const Color separatorLight = Color(0xFFE8E8ED);

  // ─── 圆角（统一 8px 标准） ───
  /// 主圆角：按钮、卡片、容器
  static const double radius = 8.0;

  /// 小圆角：输入框、小元素
  static const double radiusSm = 6.0;

  /// 超小圆角：tag、badge
  static const double radiusXs = 4.0;

  // 兼容旧命名
  static const double radiusMd = radius;
  static const double radiusLg = 10.0;

  // ─── 间距（8 倍数体系） ───
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 12.0;
  static const double spacingLg = 16.0;
  static const double spacingXl = 24.0;
  static const double spacingXxl = 32.0;

  // ─── 字体规范 ───
  /// 优先 macOS 字体，降级 Windows 字体
  static const String fontFamily = 'SF Pro Display';
  static const List<String> fontFamilyFallback = [
    'SF Pro Text',
    'PingFang SC',
    'Segoe UI',
    'Microsoft YaHei',
    '微软雅黑',
    'Arial',
    'sans-serif',
  ];

  // 字号规范
  static const double fontSizeTitle = 16.0;
  static const double fontSizeBody = 13.0;
  static const double fontSizeCaption = 11.0;

  // ─── 交通灯色 ───
  static const Color trafficClose = Color(0xFFFF5F57);
  static const Color trafficMinimize = Color(0xFFFEBC2E);
  static const Color trafficZoom = Color(0xFF28C840);

  /// Material 主题数据
  static ThemeData get theme {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: const ColorScheme.light(
        primary: primary,
        surface: surface,
        onSurface: textPrimary,
        error: danger,
      ),
      scaffoldBackgroundColor: windowBackground,
      dividerColor: separator,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: surfaceHover,
      listTileTheme: const ListTileThemeData(
        selectedColor: textSelected,
        iconColor: textSecondary,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: separatorLight),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: fontSizeBody,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      // 统一按钮圆角
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHover,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
    return base.copyWith(
      textTheme: base.textTheme.apply(fontFamilyFallback: fontFamilyFallback),
    );
  }
}
