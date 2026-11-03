import 'dart:convert';
import 'dart:io';

import 'package:cuadrante/features/share_link/data/share_link_api.dart';
import 'package:cuadrante/features/share_link/domain/share_token.dart';
import 'package:flutter_test/flutter_test.dart';

/// A stand-in for the worker on the loopback interface: records what it
/// gets and answers what the test says.
class FakeWorker {
  late HttpServer server;
  final requests =
      <
        ({String method, String path, String? auth, String? type, String body})
      >[];
  int status = 204;
  Map<String, String> headers = {};
  Duration delay = Duration.zero;

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final body = await utf8.decodeStream(request);
      requests.add((
        method: request.method,
        path: request.uri.path,
        auth: request.headers.value(HttpHeaders.authorizationHeader),
        type: request.headers.value(HttpHeaders.contentTypeHeader),
        body: body,
      ));
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      request.response.statusCode = status;
      headers.forEach(request.response.headers.set);
      await request.response.close();
    });
  }

  Uri get base => Uri.parse('http://127.0.0.1:${server.port}/base');

  Future<void> stop() => server.close(force: true);
}

void main() {
  late FakeWorker worker;
  late HttpShareLinkApi api;
  final token = ShareToken.generate();

  setUp(() async {
    worker = FakeWorker();
    await worker.start();
    api = HttpShareLinkApi(worker.base, timeout: const Duration(seconds: 2));
  });

  tearDown(() => worker.stop());

  test('the URL holds only the feed id', () {
    final url = api.feedUrl(token);
    expect(url.path, '/base/f/${token.feedId}.ics');
    expect(url.toString(), isNot(contains(token.value)));
    expect(url.toString(), isNot(contains(token.writeKey)));
    expect(
      webcalUrl(Uri.parse('https://a.com/f/x.ics')).toString(),
      'webcal://a.com/f/x.ics',
    );
  });

  test('publish PUTs the feed with the write key', () async {
    await api.publish(token, 'BEGIN:VCALENDAR\r\nSUMMARY:Mañana\r\n');
    final r = worker.requests.single;
    expect(r.method, 'PUT');
    expect(r.path, '/base/f/${token.feedId}.ics');
    expect(r.auth, 'Bearer ${token.writeKey}');
    expect(r.type, 'text/calendar; charset=utf-8');
    expect(r.body, 'BEGIN:VCALENDAR\r\nSUMMARY:Mañana\r\n');
  });

  test('revoke DELETEs with the write key; a missing feed is fine', () async {
    await api.revoke(token);
    expect(worker.requests.single.method, 'DELETE');
    expect(worker.requests.single.auth, 'Bearer ${token.writeKey}');
    worker.status = 404;
    await api.revoke(token);
  });

  Future<ShareLinkException> failure(Future<void> Function() call) async {
    try {
      await call();
    } on ShareLinkException catch (e) {
      return e;
    }
    fail('expected a ShareLinkException');
  }

  test('maps the answers of the worker', () async {
    worker.status = 429;
    worker.headers = {'Retry-After': '17'};
    final limited = await failure(() => api.publish(token, 'x'));
    expect(limited.failure, ShareLinkFailure.rateLimited);
    expect(limited.retryAfter, const Duration(seconds: 17));
    worker.headers = {};

    worker.status = 413;
    expect(
      (await failure(() => api.publish(token, 'x'))).failure,
      ShareLinkFailure.tooLarge,
    );
    worker.status = 403;
    expect(
      (await failure(() => api.publish(token, 'x'))).failure,
      ShareLinkFailure.rejected,
    );
    expect(
      (await failure(() => api.revoke(token))).failure,
      ShareLinkFailure.rejected,
    );
    worker.status = 410;
    expect(
      (await failure(() => api.publish(token, 'x'))).failure,
      ShareLinkFailure.revoked,
    );
    // Revoking an already revoked link is fine.
    await api.revoke(token);
    worker.status = 500;
    expect(
      (await failure(() => api.publish(token, 'x'))).failure,
      ShareLinkFailure.server,
    );
  });

  test('never follows a redirect with the key', () async {
    final other = FakeWorker();
    await other.start();
    addTearDown(other.stop);
    worker.status = 307;
    worker.headers = {'Location': '${other.base}/f/${token.feedId}.ics'};
    expect(
      (await failure(() => api.publish(token, 'x'))).failure,
      ShareLinkFailure.server,
    );
    expect(other.requests, isEmpty);
  });

  test('no server and a slow server are network failures', () async {
    final port = worker.server.port;
    await worker.stop();
    final dead = HttpShareLinkApi(Uri.parse('http://127.0.0.1:$port'));
    expect(
      (await failure(() => dead.publish(token, 'x'))).failure,
      ShareLinkFailure.network,
    );

    final slow = FakeWorker()..delay = const Duration(seconds: 2);
    await slow.start();
    addTearDown(slow.stop);
    final impatient = HttpShareLinkApi(
      slow.base,
      timeout: const Duration(milliseconds: 200),
    );
    expect(
      (await failure(() => impatient.publish(token, 'x'))).failure,
      ShareLinkFailure.network,
    );
  });

  test('the exception says nothing secret', () {
    const e = ShareLinkException(ShareLinkFailure.network);
    expect(e.toString(), 'ShareLinkException(network)');
  });
}
