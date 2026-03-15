import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sujin_tms_app/core/auth/session_controller.dart';
import 'package:sujin_tms_app/core/theme/app_theme.dart';
import 'package:sujin_tms_app/features/auth/presentation/login_screen.dart';

void main() {
  testWidgets('앱이 로그인 화면에서 수진 TMS 브랜딩을 표시한다', (WidgetTester tester) async {
    await initializeDateFormatting('ko_KR');
    SharedPreferences.setMockInitialValues({});
    await SessionController.bootstrap();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const LoginScreen(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('수진 TMS'), findsWidgets);
  });
}
