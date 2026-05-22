import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gerrit_api/gerrit_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Resolved once at startup.
///
/// - **Debug**: points at the local dev CORS proxy on `localhost:8080`.
/// - **Web release**: derives `<host><base path>gerrit-api` from
///   `Uri.base`, so the same build works at any deploy path
///   (`/gerrit-dashboard-v2/`, `/`, anywhere). The proxied path is a
///   sibling of the app's static files.
/// - **Native release**: hits Gerrit directly (no proxy needed, no
///   browser CORS to satisfy).
String _resolveDefaultHost() {
  if (kDebugMode) return 'localhost:8080';
  if (kIsWeb) {
    final base = Uri.base;
    final path = base.path.endsWith('/') ? base.path : '${base.path}/';
    return '${base.host}${path}gerrit-api';
  }
  return 'dart-review.googlesource.com';
}

String _resolveDefaultScheme() {
  if (kDebugMode) return 'http';
  if (kIsWeb) return Uri.base.scheme;
  return 'https';
}

final String defaultHost = _resolveDefaultHost();
final String defaultScheme = _resolveDefaultScheme();
const String defaultProject = 'sdk';

/// The actual Gerrit web UI, used by "Open in Gerrit" links. Separate
/// from [defaultHost] because the API path may be a same-origin proxy.
const String defaultWebHost = 'dart-review.googlesource.com';

const _kHost = 'gerrit.host';
const _kProject = 'gerrit.project';
const _kScheme = 'gerrit.scheme';
const _kWebHost = 'gerrit.webHost';
const _kThemeMode = 'gerrit.themeMode';
const _kUser = 'gerrit.user';
const _kSchemaVersion = 'gerrit.schemaVersion';

/// Bump when defaults change in a way that should override a user's
/// previously persisted values.
const _currentSchemaVersion = 3;

@immutable
class GerritSettings {
  final String scheme;
  final String host;
  final String webHost;
  final String project;
  final String user;
  final ThemeMode themeMode;

  const GerritSettings({
    required this.scheme,
    required this.host,
    required this.project,
    this.webHost = defaultWebHost,
    this.user = '',
    this.themeMode = ThemeMode.system,
  });

  factory GerritSettings.fromDefaults() => GerritSettings(
        scheme: defaultScheme,
        host: defaultHost,
        project: defaultProject,
      );

  Uri get baseUri => Uri.parse('$scheme://$host');

  GerritSettings copyWith({
    String? scheme,
    String? host,
    String? webHost,
    String? project,
    String? user,
    ThemeMode? themeMode,
  }) =>
      GerritSettings(
        scheme: scheme ?? this.scheme,
        host: host ?? this.host,
        webHost: webHost ?? this.webHost,
        project: project ?? this.project,
        user: user ?? this.user,
        themeMode: themeMode ?? this.themeMode,
      );
}

class SettingsController extends Notifier<GerritSettings> {
  SharedPreferences? _prefs;

  @override
  GerritSettings build() {
    _load();
    return GerritSettings.fromDefaults();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    final storedVersion = prefs.getInt(_kSchemaVersion) ?? 0;
    if (storedVersion < _currentSchemaVersion) {
      await prefs.remove(_kHost);
      await prefs.remove(_kScheme);
      await prefs.remove(_kWebHost);
      await prefs.setInt(_kSchemaVersion, _currentSchemaVersion);
    }
    state = GerritSettings(
      scheme: prefs.getString(_kScheme) ?? defaultScheme,
      host: prefs.getString(_kHost) ?? defaultHost,
      webHost: prefs.getString(_kWebHost) ?? defaultWebHost,
      project: prefs.getString(_kProject) ?? defaultProject,
      user: prefs.getString(_kUser) ?? '',
      themeMode: _parseThemeMode(prefs.getString(_kThemeMode)),
    );
  }

  Future<void> update({
    String? scheme,
    String? host,
    String? webHost,
    String? project,
    String? user,
    ThemeMode? themeMode,
  }) async {
    state = state.copyWith(
      scheme: scheme,
      host: host,
      webHost: webHost,
      project: project,
      user: user,
      themeMode: themeMode,
    );
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    if (scheme != null) await prefs.setString(_kScheme, scheme);
    if (host != null) await prefs.setString(_kHost, host);
    if (webHost != null) await prefs.setString(_kWebHost, webHost);
    if (project != null) await prefs.setString(_kProject, project);
    if (user != null) await prefs.setString(_kUser, user);
    if (themeMode != null) {
      await prefs.setString(_kThemeMode, themeMode.name);
    }
  }
}

ThemeMode _parseThemeMode(String? raw) {
  switch (raw) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

final settingsProvider =
    NotifierProvider<SettingsController, GerritSettings>(SettingsController.new);

/// A [GerritClient] keyed on the current host/scheme. Rebuilt when
/// settings change.
final gerritClientProvider = Provider<GerritClient>((ref) {
  final settings = ref.watch(settingsProvider);
  final client = GerritClient(host: settings.baseUri);
  ref.onDispose(client.close);
  return client;
});

/// A route-driven override threaded into `OverviewPage` from the
/// `/u/:user` route. Merging is done inline in the page; we don't keep
/// it in a global provider so the lifecycle is naturally bound to the
/// route instance.
@immutable
class ScopeOverride {
  final String? user;
  final String? project;
  const ScopeOverride({this.user, this.project});

  bool get isEmpty =>
      (user == null || user!.isEmpty) &&
      (project == null || project!.isEmpty);

  /// Merge this override on top of [base].
  GerritSettings applyTo(GerritSettings base) {
    if (isEmpty) return base;
    return base.copyWith(
      user: (user?.isNotEmpty ?? false) ? user : null,
      project: (project?.isNotEmpty ?? false) ? project : null,
    );
  }
}

/// User-facing filter chips. Status filters (open/merged/abandoned)
/// contribute a clause to the server-side Gerrit query; attribute
/// filters (wip/private) are applied client-side after results land.
enum DashboardFilter {
  open('Open', statusClause: 'status:open'),
  merged('Merged', statusClause: 'status:merged'),
  abandoned('Abandoned', statusClause: 'status:abandoned'),
  wip('WIP'),
  private('Private');

  final String label;
  final String? statusClause;
  const DashboardFilter(this.label, {this.statusClause});

  bool get isStatus => statusClause != null;
  bool get isAttribute => statusClause == null;
}

const Set<DashboardFilter> defaultFilters = {
  DashboardFilter.open,
  DashboardFilter.merged,
  DashboardFilter.wip,
  DashboardFilter.private,
  // Abandoned is intentionally NOT in the default set.
};

const _kFilters = 'gerrit.filters';

class FilterController extends Notifier<Set<DashboardFilter>> {
  SharedPreferences? _prefs;

  @override
  Set<DashboardFilter> build() {
    _load();
    return {...defaultFilters};
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    final raw = prefs.getStringList(_kFilters);
    if (raw == null) return;
    final byName = {for (final f in DashboardFilter.values) f.name: f};
    state = {
      for (final name in raw) ?byName[name],
    };
  }

  Future<void> _persist() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setStringList(
      _kFilters,
      state.map((f) => f.name).toList(),
    );
  }

  void toggle(DashboardFilter f) {
    final next = {...state};
    if (next.contains(f)) {
      next.remove(f);
    } else {
      next.add(f);
    }
    state = next;
    _persist();
  }

  /// Cmd/Ctrl-click semantics: select only this filter, deselect the rest.
  /// Idempotent, re-applying when already exclusive is a no-op.
  void selectOnly(DashboardFilter f) {
    state = {f};
    _persist();
  }
}

final filterProvider =
    NotifierProvider<FilterController, Set<DashboardFilter>>(
        FilterController.new);

// ---------------------------------------------------------------------------
// Starred CLs (client-side bookmarks). Stars are anonymous: stored only in
// the browser's localStorage, never sent to Gerrit.
//
// The key shape `<webHost>:<project>:<number>` lets stars stay scoped to
// the actual Gerrit instance + repo, so the same CL number across projects
// doesn't collide.
// ---------------------------------------------------------------------------

const _kStarred = 'gerrit.starred';

String starKey(String webHost, String project, int number) =>
    '$webHost:$project:$number';

class StarredController extends Notifier<Set<String>> {
  SharedPreferences? _prefs;

  @override
  Set<String> build() {
    _load();
    return const {};
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    state = (prefs.getStringList(_kStarred) ?? const []).toSet();
  }

  Future<void> _persist() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setStringList(_kStarred, state.toList());
  }

  void toggle(String key) {
    final next = {...state};
    if (!next.add(key)) next.remove(key);
    state = next;
    _persist();
  }

  /// Numbers of CLs starred under the given `webHost:project` scope.
  List<int> numbersFor(String webHost, String project) {
    final prefix = '$webHost:$project:';
    final out = <int>[];
    for (final k in state) {
      if (!k.startsWith(prefix)) continue;
      final n = int.tryParse(k.substring(prefix.length));
      if (n != null) out.add(n);
    }
    return out;
  }
}

final starredProvider = NotifierProvider<StarredController, Set<String>>(
    StarredController.new);

/// Builds the Gerrit-side status clause from the currently-enabled
/// status chips. Returns `null` when *no* status chips are selected,
/// which the caller should treat as "show no results".
String? buildStatusClause(Set<DashboardFilter> selected) {
  final statuses = [
    for (final f in selected)
      if (f.isStatus) f.statusClause!,
  ];
  if (statuses.isEmpty) return null;
  if (statuses.length == 1) return statuses.first;
  return '(${statuses.join(' OR ')})';
}

/// True when [c] should be visible given the active attribute chips.
bool passesAttributeFilters(ChangeInfo c, Set<DashboardFilter> selected) {
  if (c.work && !selected.contains(DashboardFilter.wip)) return false;
  if (c.isPrivate && !selected.contains(DashboardFilter.private)) {
    return false;
  }
  return true;
}
