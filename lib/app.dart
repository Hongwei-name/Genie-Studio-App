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
      // 全局鼠标样式设置
      // 可选: basic(箭头), click(手型), text(I形), help(帮助), progress(忙碌)
      builder: (context, child) {
        return MouseRegion(
          cursor: SystemMouseCursors.basic,  // 修改这里改变全局默认鼠标
          child: child!,
        );
      },
      home: const HomeShell(),
    );
  }
}
