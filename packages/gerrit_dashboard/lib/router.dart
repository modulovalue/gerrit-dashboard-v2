import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'pages/change_detail_page.dart';
import 'pages/overview_page.dart';
import 'pages/settings_page.dart';
import 'settings/settings_controller.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const OverviewPage(),
    ),
    GoRoute(
      path: '/u/:user',
      builder: (context, state) {
        final raw = state.pathParameters['user'] ?? '';
        final user = Uri.decodeComponent(raw);
        final project = state.uri.queryParameters['project'];
        return OverviewPage(
          scope: ScopeOverride(user: user, project: project),
        );
      },
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: '/c/:number',
      builder: (context, state) {
        final raw = state.pathParameters['number'] ?? '';
        final number = int.tryParse(raw);
        if (number == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Bad URL')),
            body: Center(child: Text('Not a valid CL number: $raw')),
          );
        }
        return ChangeDetailPage(number: number);
      },
    ),
  ],
);
