import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '生活事项',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      routerConfig: appRouter,
    );
  }
}
