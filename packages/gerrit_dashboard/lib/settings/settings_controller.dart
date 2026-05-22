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
