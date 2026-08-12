import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/shell/home_shell.dart';

/// 应用根 Widget
class GenieReviewApp extends StatelessWidget {
  const GenieReviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '智元标注审核助手',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const HomeShell(),
    );
  }
}
