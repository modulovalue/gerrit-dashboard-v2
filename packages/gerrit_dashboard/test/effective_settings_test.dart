import 'package:flutter_test/flutter_test.dart';
import 'package:gerrit_dashboard/settings/settings_controller.dart';

GerritSettings _base() => const GerritSettings(
      scheme: 'https',
      host: 'h.example.com',
      project: 'sdk',
      user: 'bob',
    );

void main() {
  test('empty override is identity', () {
    final base = _base();
    expect(const ScopeOverride().applyTo(base).user, 'bob');
    expect(const ScopeOverride(user: '').applyTo(base).user, 'bob');
  });

  test('user override replaces saved user', () {
    final base = _base();
    final out = const ScopeOverride(user: 'alice').applyTo(base);
    expect(out.user, 'alice');
    expect(out.project, 'sdk');
  });

  test('user + project override both apply', () {
    final base = _base();
    final out = const ScopeOverride(user: 'alice', project: 'flutter')
        .applyTo(base);
    expect(out.user, 'alice');
    expect(out.project, 'flutter');
  });

  test('blank project field falls back to saved project', () {
    final base = _base();
    final out =
        const ScopeOverride(user: 'alice', project: '').applyTo(base);
    expect(out.user, 'alice');
    expect(out.project, 'sdk');
  });
}
