import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';

class GerritDashboardApp extends ConsumerWidget {
  const GerritDashboardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Gerrit Dart Dashboard',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        // Dart brand blue.
        colorSchemeSeed: const Color(0xFF0175C2),
        brightness: Brightness.dark,
      ),
      routerConfig: appRouter,
    );
  }
}
