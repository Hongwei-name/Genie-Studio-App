import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/shell/home_shell.dart';

/// 应用根 Widget
class ZeroKGenieApp extends StatelessWidget {
  const ZeroKGenieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'zero_K-Genie',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      // 全局鼠标样式设置
      builder: (context, child) {
        return MouseRegion(
          cursor: SystemMouseCursors.basic,
          child: child!,
        );
      },
      home: const HomeShell(),
    );
  }
}
