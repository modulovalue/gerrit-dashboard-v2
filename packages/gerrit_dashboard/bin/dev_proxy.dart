// Tiny dev-only CORS proxy for Gerrit.
//
// Listens on localhost:<port> and forwards every request to a configurable
// upstream Gerrit host, copying headers/body in both directions and
// stamping permissive CORS headers on the response so a Flutter web
// (Wasm) app served from a different origin can read the JSON.
//
// Usage:
//   dart run gerrit_dashboard:dev_proxy
//   dart run gerrit_dashboard:dev_proxy --port 8080 \
//       --upstream https://dart-review.googlesource.com
//
// Intentionally pure dart:io so it has no extra deps and starts in <1s.

import 'dart:async';
import 'dart:io';

const _defaultPort = 8080;
const _defaultUpstream = 'https://dart-review.googlesource.com';

Future<void> main(List<String> args) async {
  var port = _defaultPort;
  var upstream = Uri.parse(_defaultUpstream);

  for (var i = 0; i < args.length; i++) {
    switch (args[i]) {
      case '--port' || '-p':
        port = int.parse(args[++i]);
      case '--upstream' || '-u':
        upstream = Uri.parse(args[++i]);
      case '--help' || '-h':
        stdout.writeln(
          'Usage: dart run gerrit_dashboard:dev_proxy '
          '[--port <p>] [--upstream <url>]',
        );
        return;
      default:
        stderr.writeln('Unknown argument: ${args[i]}');
        exit(64);
    }
  }

  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    ..idleTimeout = const Duration(seconds: 30)
    // Pass the gzip-encoded body through unchanged so it matches the
    // upstream `content-encoding: gzip` header we forward. Without this,
    // dart:io transparently decompresses on our end but we still claim
    // gzip downstream, and the browser fails with "network error".
    ..autoUncompress = false;

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  stdout.writeln(
    'gerrit dev proxy listening on http://localhost:$port  ->  $upstream',
  );

  await for (final request in server) {
    unawaited(_handle(request, upstream, client));
  }
}

Future<void> _handle(
  HttpRequest request,
  Uri upstream,
  HttpClient client,
) async {
  final response = request.response;

  // CORS preflight.
  if (request.method == 'OPTIONS') {
    _writeCorsHeaders(response, request);
    response.statusCode = HttpStatus.noContent;
    await response.close();
    return;
  }

  final upstreamUri = upstream.replace(
    path: request.uri.path,
    query: request.uri.hasQuery ? request.uri.query : null,
  );

  try {
    final upstreamRequest = await client.openUrl(request.method, upstreamUri);
    upstreamRequest.followRedirects = false;

    request.headers.forEach((name, values) {
      final lower = name.toLowerCase();
      if (lower == 'host' ||
          lower == 'origin' ||
          lower == 'referer' ||
          lower == 'cookie' ||
          lower == 'authorization' ||
          lower.startsWith('sec-') ||
          lower.startsWith('access-control-')) {
        return;
      }
      for (final v in values) {
        upstreamRequest.headers.add(name, v);
      }
    });
    upstreamRequest.headers.set('Host', upstreamUri.host);

    if (request.method != 'GET' && request.method != 'HEAD') {
      await upstreamRequest.addStream(request);
    }

    final upstreamResponse = await upstreamRequest.close();

    response.statusCode = upstreamResponse.statusCode;
    upstreamResponse.headers.forEach((name, values) {
      final lower = name.toLowerCase();
      if (lower == 'set-cookie' ||
          lower == 'transfer-encoding' ||
          lower == 'connection' ||
          lower == 'content-length' ||
          lower.startsWith('access-control-')) {
        return;
      }
      for (final v in values) {
        response.headers.add(name, v);
      }
    });
    _writeCorsHeaders(response, request);

    await upstreamResponse.pipe(response);
  } catch (e, st) {
    stderr.writeln('proxy error for ${request.uri}: $e\n$st');
    if (!response.headers.persistentConnection) {
      // Already started; nothing we can do.
      return;
    }
    response.statusCode = HttpStatus.badGateway;
    _writeCorsHeaders(response, request);
    response.headers.contentType = ContentType.text;
    response.write('proxy error: $e');
    await response.close();
  }
}

void _writeCorsHeaders(HttpResponse response, HttpRequest request) {
  final origin = request.headers.value('origin') ?? '*';
  response.headers
    ..set('Access-Control-Allow-Origin', origin)
    ..set('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS')
    ..set('Access-Control-Allow-Headers',
        request.headers.value('access-control-request-headers') ??
            'Accept, Content-Type')
    ..set('Access-Control-Max-Age', '600')
    ..set('Vary', 'Origin');
}
