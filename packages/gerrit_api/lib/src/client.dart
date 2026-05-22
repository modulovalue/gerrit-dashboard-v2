import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import 'exceptions.dart';
import 'models/account_info.dart';
import 'models/change_info.dart';
import 'models/change_message_info.dart';
import 'models/project_info.dart';
import 'models/revision_info.dart';
import 'options.dart';
import 'xssi.dart';

/// Anonymous, read-only client for the Gerrit REST API.
///
/// Talks to the `/changes/`, `/projects/`, and `/accounts/` endpoints with
/// no `/a/` prefix and no auth headers. Designed to run in a browser
/// (Wasm) or on native.
class GerritClient {
  final Uri host;
  final http.Client _http;
  final bool _ownsClient;

  /// [host] is a full base URI (scheme + authority, optionally path), e.g.
  /// `Uri.parse('https://dart-review.googlesource.com')`. The path of
  /// [host] is preserved as a prefix for all requests, which lets you
  /// point at a reverse-proxy like `http://localhost:8080/gerrit`.
  GerritClient({required this.host, http.Client? httpClient})
      : _http = httpClient ?? http.Client(),
        _ownsClient = httpClient == null;

  void close() {
    if (_ownsClient) _http.close();
  }

  /// `GET /changes/?q=<query>&o=...`
  ///
  /// Returns the page of changes plus a `hasMore` flag derived from the
  /// `_more_changes: true` marker Gerrit sets on the last item when the
  /// server-side result set extends beyond this page. Combine with
  /// [start] / [limit] for pagination.
  Future<({List<ChangeInfo> changes, bool hasMore})> queryChanges(
    String query, {
    Set<ChangeOption> options = const {},
    int? limit,
    int? start,
  }) async {
    final params = <String, List<String>>{
      'q': [query],
      if (options.isNotEmpty)
        'o': [for (final o in options) o.wire],
      if (limit != null) 'n': [limit.toString()],
      if (start != null) 'S': [start.toString()],
    };
    final json = await _getJson('/changes/', params);
    if (json is! List) {
      throw GerritException(
        'Expected JSON array from /changes/, got ${json.runtimeType}',
      );
    }
    final changes = <ChangeInfo>[];
    var hasMore = false;
    for (final item in json) {
      if (item is Map<String, dynamic>) {
        changes.add(ChangeInfo.fromJson(item));
        // Gerrit sets `_more_changes: true` only on the trailing element
        // when there are more matches beyond this page.
        if (item['_more_changes'] == true) hasMore = true;
      }
    }
    return (changes: changes, hasMore: hasMore);
  }

  /// `GET /changes/<number>?o=...`
  Future<ChangeInfo> getChange(
    int number, {
    Set<ChangeOption> options = const {},
  }) async {
    final params = <String, List<String>>{
      if (options.isNotEmpty)
        'o': [for (final o in options) o.wire],
    };
    final json = await _getJson('/changes/$number', params);
    if (json is! Map<String, dynamic>) {
      throw GerritException(
        'Expected JSON object from /changes/$number, got ${json.runtimeType}',
      );
    }
    return ChangeInfo.fromJson(json);
  }

  /// `GET /changes/<number>/detail?o=...`
  ///
  /// Returns extra detail (labels, messages, reviewers). Convenient when
  /// rendering a single change page.
  Future<ChangeInfo> getChangeDetail(
    int number, {
    Set<ChangeOption> options = const {
      ChangeOption.currentRevision,
      ChangeOption.currentCommit,
      ChangeOption.currentFiles,
      ChangeOption.detailedAccounts,
      ChangeOption.detailedLabels,
      ChangeOption.messages,
    },
  }) async {
    final params = <String, List<String>>{
      if (options.isNotEmpty)
        'o': [for (final o in options) o.wire],
    };
    final json = await _getJson('/changes/$number/detail', params);
    if (json is! Map<String, dynamic>) {
      throw GerritException(
        'Expected JSON object from /changes/$number/detail, '
        'got ${json.runtimeType}',
      );
    }
    return ChangeInfo.fromJson(json);
  }

  /// `GET /changes/<number>/revisions/<revisionId>`
  Future<RevisionInfo> getRevision(int number, String revisionId) async {
    final json = await _getJson(
      '/changes/$number/revisions/$revisionId',
      const {},
    );
    if (json is! Map<String, dynamic>) {
      throw GerritException(
        'Expected JSON object from /changes/$number/revisions/$revisionId',
      );
    }
    return RevisionInfo.fromJson(revisionId, json);
  }

  /// `GET /changes/<number>/messages`
  Future<List<ChangeMessageInfo>> getMessages(int number) async {
    final json = await _getJson('/changes/$number/messages', const {});
    if (json is! List) {
      throw GerritException(
        'Expected JSON array from /changes/$number/messages',
      );
    }
    return [
      for (final item in json)
        if (item is Map<String, dynamic>) ChangeMessageInfo.fromJson(item),
    ];
  }

  /// `GET /projects/<name>`
  Future<ProjectInfo> getProject(String name) async {
    final json = await _getJson('/projects/${Uri.encodeComponent(name)}',
        const {});
    if (json is! Map<String, dynamic>) {
      throw GerritException('Expected JSON object from /projects/$name');
    }
    return ProjectInfo.fromJson(name, json);
  }

  /// `GET /accounts/<idOrUsername>`
  Future<AccountInfo> getAccount(String idOrUsername) async {
    final json =
        await _getJson('/accounts/${Uri.encodeComponent(idOrUsername)}',
            const {});
    if (json is! Map<String, dynamic>) {
      throw GerritException('Expected JSON object from /accounts/$idOrUsername');
    }
    return AccountInfo.fromJson(json);
  }

  @visibleForTesting
  Uri buildUri(String path, Map<String, List<String>> params) {
    final hostPath = host.path.endsWith('/')
        ? host.path.substring(0, host.path.length - 1)
        : host.path;
    final fullPath = '$hostPath$path';
    return host.replace(
      path: fullPath,
      queryParameters: params.isEmpty ? null : params,
    );
  }

  Future<Object?> _getJson(String path, Map<String, List<String>> params) async {
    final uri = buildUri(path, params);
    final http.Response response;
    try {
      response = await _http.get(uri, headers: const {'Accept': 'application/json'});
    } catch (e) {
      throw GerritException('Network error talking to $uri: $e');
    }

    if (response.statusCode == 404) {
      throw GerritException(
        'Not found: $uri',
        statusCode: response.statusCode,
        body: response.body,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw GerritException(
        'Request failed: $uri',
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    final cleaned = stripXssiPrefix(response.body);
    try {
      return jsonDecode(cleaned);
    } on FormatException catch (e) {
      throw GerritException(
        'Malformed JSON from $uri: ${e.message}',
        body: cleaned,
      );
    }
  }
}
