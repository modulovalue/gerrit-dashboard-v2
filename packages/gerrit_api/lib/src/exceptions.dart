/// Thrown by [GerritClient] when a request fails.
class GerritException implements Exception {
  final String message;
  final int? statusCode;
  final String? body;

  GerritException(this.message, {this.statusCode, this.body});

  @override
  String toString() {
    final code = statusCode == null ? '' : ' [HTTP $statusCode]';
    return 'GerritException$code: $message';
  }
}
