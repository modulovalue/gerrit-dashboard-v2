import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gerrit_dashboard/settings/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('no override -> effective == base', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final base = container.read(settingsProvider);
    final effective = container.read(effectiveSettingsProvider);
    expect(effective.user, base.user);
    expect(effective.project, base.project);
  });

  test('user override is applied without persisting', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(scopeOverrideProvider.notifier).state =
        const ScopeOverride(user: 'alice');
    final effective = container.read(effectiveSettingsProvider);
    expect(effective.user, 'alice');
    // The persisted settings are untouched.
    expect(container.read(settingsProvider).user, '');
  });

  test('user + project override both apply', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(scopeOverrideProvider.notifier).state =
        const ScopeOverride(user: 'alice', project: 'flutter');
    final effective = container.read(effectiveSettingsProvider);
    expect(effective.user, 'alice');
    expect(effective.project, 'flutter');
  });

  test('empty override fields fall back to base', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(scopeOverrideProvider.notifier).state =
        const ScopeOverride(user: 'alice', project: '');
    final effective = container.read(effectiveSettingsProvider);
    expect(effective.user, 'alice');
    expect(effective.project, defaultProject);
  });
}
