import 'package:flutter_test/flutter_test.dart';
import 'package:gerrit_api/gerrit_api.dart';
import 'package:gerrit_dashboard/settings/settings_controller.dart';

ChangeInfo _ci({bool wip = false, bool private = false}) =>
    ChangeInfo.fromJson(<String, Object?>{
      '_number': 1,
      'change_id': 'I',
      'subject': 'x',
      'status': 'NEW',
      'project': 'p',
      'branch': 'main',
      'work_in_progress': wip,
      'is_private': private,
    });

void main() {
  group('buildStatusClause', () {
    test('no status chips -> null', () {
      expect(buildStatusClause(const {}), isNull);
      expect(
        buildStatusClause(const {DashboardFilter.wip}),
        isNull,
      );
    });

    test('single status -> bare clause', () {
      expect(
        buildStatusClause(const {DashboardFilter.open}),
        'status:open',
      );
      expect(
        buildStatusClause(const {DashboardFilter.merged}),
        'status:merged',
      );
    });

    test('multiple statuses -> parenthesized OR', () {
      final out = buildStatusClause(const {
        DashboardFilter.open,
        DashboardFilter.merged,
      });
      // Order isn't guaranteed by Set, so check both forms.
      expect(
        out == '(status:open OR status:merged)' ||
            out == '(status:merged OR status:open)',
        isTrue,
        reason: 'got $out',
      );
    });
  });

  group('passesAttributeFilters', () {
    test('WIP chip on includes WIP changes', () {
      expect(
        passesAttributeFilters(
            _ci(wip: true), const {DashboardFilter.wip}),
        isTrue,
      );
    });

    test('WIP chip off hides WIP changes', () {
      expect(
        passesAttributeFilters(_ci(wip: true), const {}),
        isFalse,
      );
    });

    test('Private chip off hides private changes', () {
      expect(
        passesAttributeFilters(_ci(private: true), const {}),
        isFalse,
      );
    });

    test('Non-WIP non-private change passes empty filter set', () {
      expect(
        passesAttributeFilters(_ci(), const {}),
        isTrue,
      );
    });
  });

  test('defaultFilters excludes Abandoned', () {
    expect(defaultFilters, contains(DashboardFilter.open));
    expect(defaultFilters, contains(DashboardFilter.merged));
    expect(defaultFilters, contains(DashboardFilter.wip));
    expect(defaultFilters, contains(DashboardFilter.private));
    expect(defaultFilters, isNot(contains(DashboardFilter.abandoned)));
  });
}
