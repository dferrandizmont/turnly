import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/share_token.dart';

/// Why the worker did not do what was asked.
enum ShareLinkFailure {
  /// No connection, DNS, timeout, TLS: try again later.
  network,

  /// Too many uploads in a short time (HTTP 429).
  rateLimited,

  /// The feed is larger than the worker accepts (HTTP 413).
  tooLarge,

  /// The worker refused the key (HTTP 401/403): the link is not ours any
  /// more, or the request was malformed (400).
  rejected,

  /// The link was revoked (HTTP 410): it can never be published again.
  /// The app forgets the token.
  revoked,

  /// Anything else (5xx, unexpected answers).
  server,
}

class ShareLinkException implements Exception {
  const ShareLinkException(this.failure, {this.retryAfter});

  final ShareLinkFailure failure;

  /// The `Retry-After` of a 429, when the worker sent one.
  final Duration? retryAfter;

  /// No URL, no key, no body: nothing secret ends up in a log.
  @override
  String toString() => 'ShareLinkException(${failure.name})';
}

/// The worker that serves the feeds (`worker/`). Tests use a fake.
abstract class ShareLinkApi {
  /// The public `https` URL of the feed of [token].
  Uri feedUrl(ShareToken token);

  /// Uploads [ics] as the feed of [token], replacing the previous one.
  Future<void> publish(ShareToken token, String ics);

  /// Deletes the feed of [token] (the worker keeps a tombstone, so the link
  /// can never be published again). A feed that was already gone counts as
  /// deleted.
  Future<void> revoke(ShareToken token);
}

/// The `webcal://` form of an `https` feed URL: calendar apps (Apple's, in
/// particular) open it as a subscription.
Uri webcalUrl(Uri https) => https.replace(scheme: 'webcal');

/// [ShareLinkApi] over `dart:io` (no extra package).
///
/// - `PUT  <base>/f/<feedId>.ics` with `Authorization: Bearer <writeKey>`
///   and the feed as `text/calendar; charset=utf-8`.
/// - `DELETE <base>/f/<feedId>.ics` with the same header.
///
/// Redirects are never followed (the key must reach only [base]) and every
/// request has a [timeout].
class HttpShareLinkApi implements ShareLinkApi {
  HttpShareLinkApi(
    this.base, {
    HttpClient Function()? clientFactory,
    this.timeout = const Duration(seconds: 20),
  }) : _clientFactory = clientFactory ?? HttpClient.new;

  /// The worker, without a trailing slash (`AppConfig.shareLinkBase`).
  final Uri base;
  final Duration timeout;
  final HttpClient Function() _clientFactory;

  @override
  Uri feedUrl(ShareToken token) =>
      base.replace(path: '${base.path}/f/${token.feedId}.ics');

  @override
  Future<void> publish(ShareToken token, String ics) async {
    final status = await _send('PUT', token, utf8.encode(ics));
    if (status.code == 200 || status.code == 201 || status.code == 204) return;
    throw _failureOf(status);
  }

  @override
  Future<void> revoke(ShareToken token) async {
    final status = await _send('DELETE', token, null);
    // Already gone or already revoked: nothing left to delete.
    if (status.code == 200 ||
        status.code == 204 ||
        status.code == 404 ||
        status.code == 410) {
      return;
    }
    throw _failureOf(status);
  }

  ShareLinkException _failureOf(_Status status) => switch (status.code) {
    429 => ShareLinkException(
      ShareLinkFailure.rateLimited,
      retryAfter: status.retryAfter,
    ),
    413 => const ShareLinkException(ShareLinkFailure.tooLarge),
    410 => const ShareLinkException(ShareLinkFailure.revoked),
    400 || 401 || 403 => const ShareLinkException(ShareLinkFailure.rejected),
    _ => const ShareLinkException(ShareLinkFailure.server),
  };

  Future<_Status> _send(
    String method,
    ShareToken token,
    List<int>? body,
  ) async {
    final client = _clientFactory()..connectionTimeout = timeout;
    try {
      final request = await client
          .openUrl(method, feedUrl(token))
          .timeout(timeout);
      request
        ..followRedirects = false
        ..persistentConnection = false;
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ${token.writeKey}',
      );
      if (body != null) {
        request.headers.contentType = ContentType(
          'text',
          'calendar',
          charset: 'utf-8',
        );
        request.contentLength = body.length;
        request.add(body);
      } else {
        request.contentLength = 0;
      }
      final response = await request.close().timeout(timeout);
      // The body is never read into the app: drain it and keep the status.
      await response.drain<void>().timeout(timeout);
      final retry = int.tryParse(
        response.headers.value(HttpHeaders.retryAfterHeader) ?? '',
      );
      return _Status(
        response.statusCode,
        retry == null || retry < 0 ? null : Duration(seconds: retry),
      );
    } on ShareLinkException {
      rethrow;
    } on TimeoutException {
      throw const ShareLinkException(ShareLinkFailure.network);
    } on SocketException {
      throw const ShareLinkException(ShareLinkFailure.network);
    } on HandshakeException {
      throw const ShareLinkException(ShareLinkFailure.network);
    } on HttpException {
      throw const ShareLinkException(ShareLinkFailure.network);
    } on IOException {
      throw const ShareLinkException(ShareLinkFailure.network);
    } finally {
      client.close(force: true);
    }
  }
}

class _Status {
  const _Status(this.code, this.retryAfter);

  final int code;
  final Duration? retryAfter;
}
