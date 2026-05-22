import 'dart:io';

import 'package:gerrit_api/gerrit_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

String _readFixture(String name) =>
    File('test/fixtures/$name').readAsStringSync();

void main() {
  group('GerritClient', () {
    test('queryChanges parses fixture and assembles query string', () async {
      Uri? captured;
      final mock = MockClient((request) async {
        captured = request.url;
        return http.Response(_readFixture('changes_query.json'), 200);
      });

      final client = GerritClient(
        host: Uri.parse('https://example-review.googlesource.com'),
        httpClient: mock,
      );

      final result = await client.queryChanges(
        'status:open project:sdk',
        options: const {ChangeOption.currentRevision},
        limit: 25,
      );

      expect(captured, isNotNull);
      expect(captured!.host, 'example-review.googlesource.com');
      expect(captured!.path, '/changes/');
      expect(captured!.queryParametersAll['q'], ['status:open project:sdk']);
      expect(captured!.queryParametersAll['o'], ['CURRENT_REVISION']);
      expect(captured!.queryParametersAll['n'], ['25']);

      expect(result.changes, hasLength(2));
      expect(result.hasMore, isFalse);
      expect(result.changes[0].number, 42101);
      expect(result.changes[0].subject, 'Add cool feature');
      expect(result.changes[0].status, ChangeStatus.newChange);
      expect(result.changes[0].owner?.name, 'Ada Lovelace');
      expect(result.changes[0].currentRevision,
          'deadbeef0000000000000000000000000000beef');
      expect(result.changes[1].status, ChangeStatus.merged);
    });

    test('queryChanges flags hasMore when Gerrit sets _more_changes',
        () async {
      final mock = MockClient((request) async {
        // Trailing item carries `_more_changes: true`.
        return http.Response(
          ")]}'\n"
          '[{"_number":1,"change_id":"I1","subject":"a","status":"NEW","project":"p","branch":"b"},'
          '{"_number":2,"change_id":"I2","subject":"b","status":"NEW","project":"p","branch":"b","_more_changes":true}]',
          200,
        );
      });
      final client = GerritClient(
        host: Uri.parse('https://example-review.googlesource.com'),
        httpClient: mock,
      );
      final result = await client.queryChanges('q', limit: 2);
      expect(result.changes, hasLength(2));
      expect(result.hasMore, isTrue);
    });

    test('queryChanges hasMore is false when no marker', () async {
      final mock = MockClient(
        (_) async => http.Response(")]}'\n[]", 200),
      );
      final client = GerritClient(
        host: Uri.parse('https://example.invalid'),
        httpClient: mock,
      );
      final result = await client.queryChanges('q');
      expect(result.changes, isEmpty);
      expect(result.hasMore, isFalse);
    });

    test('getChangeDetail parses files, labels, messages', () async {
      final mock = MockClient((request) async {
        expect(request.url.path, '/changes/42101/detail');
        return http.Response(_readFixture('change_detail.json'), 200);
      });

      final client = GerritClient(
        host: Uri.parse('https://example-review.googlesource.com'),
        httpClient: mock,
      );
      final change = await client.getChangeDetail(42101);

      expect(change.number, 42101);
      expect(change.currentRevisionInfo?.files, hasLength(2));
      expect(change.labels['Code-Review']?.approved, isTrue);
      expect(change.messages, hasLength(1));
      expect(change.messages.first.message, 'Uploaded patch set 1.');
    });

    test('throws GerritException on non-2xx', () async {
      final mock = MockClient((_) async => http.Response('nope', 500));
      final client = GerritClient(
        host: Uri.parse('https://example.invalid'),
        httpClient: mock,
      );
      expect(
        client.queryChanges('status:open'),
        throwsA(isA<GerritException>()
            .having((e) => e.statusCode, 'statusCode', 500)),
      );
    });

    test('throws GerritException on malformed JSON', () async {
      final mock = MockClient(
        (_) async => http.Response(")]}'\nnot json", 200),
      );
      final client = GerritClient(
        host: Uri.parse('https://example.invalid'),
        httpClient: mock,
      );
      expect(
        client.queryChanges('status:open'),
        throwsA(isA<GerritException>()),
      );
    });

    test('preserves host path prefix (proxy-friendly)', () async {
      Uri? captured;
      final mock = MockClient((request) async {
        captured = request.url;
        return http.Response(")]}'\n[]", 200);
      });
      final client = GerritClient(
        host: Uri.parse('http://localhost:8080/gerrit'),
        httpClient: mock,
      );
      await client.queryChanges('status:open');
      expect(captured!.path, '/gerrit/changes/');
    });
  });
}
