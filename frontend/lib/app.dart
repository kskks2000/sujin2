import 'package:flutter/material.dart';

import 'core/auth/session_controller.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class SujinTmsApp extends StatelessWidget {
  SujinTmsApp({
    super.key,
    required SessionController sessionController,
  }) : _router = AppRouter.createRouter(sessionController);

  final RouterConfig<Object> _router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: '수진 TMS',
      theme: AppTheme.lightTheme,
      routerConfig: _router,
    );
  }
}
