import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gerrit_api/gerrit_api.dart';
import 'package:gerrit_dashboard/settings/settings_controller.dart';
import 'package:gerrit_dashboard/widgets/change_row.dart';
import 'package:gerrit_dashboard/widgets/status_badge.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('ChangeRow renders subject and CL number', (tester) async {
    final change = ChangeInfo.fromJson(<String, Object?>{
      '_number': 12345,
      'change_id': 'I0abc',
      'subject': 'Hello world',
      'status': 'NEW',
      'project': 'sdk',
      'branch': 'main',
      'owner': {'name': 'Ada Lovelace'},
      'updated': '2026-05-22 10:00:00.000000000',
      'insertions': 5,
      'deletions': 2,
    });

    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(
          body: ChangeRow(change: change, host: 'h', project: 'sdk'),
        ),
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();

    expect(find.text('#12345'), findsOneWidget);
    expect(find.text('Hello world'), findsOneWidget);
    expect(find.text('+5 -2'), findsOneWidget);
    expect(find.byType(StatusBadge), findsOneWidget);
    expect(find.text('OPEN'), findsOneWidget);
  });

  test('settings start with defaults', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final settings = container.read(settingsProvider);
    expect(settings.host, defaultHost);
    expect(settings.project, defaultProject);
  });
}
