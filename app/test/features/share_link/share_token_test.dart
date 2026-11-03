import 'dart:math';

import 'package:cuadrante/core/config.dart';
import 'package:cuadrante/features/backup/data/backup_repository.dart';
import 'package:cuadrante/features/share_link/data/share_link_repository.dart';
import 'package:cuadrante/features/share_link/domain/share_token.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hands out 0, 1, 2... so the generated token is the bytes 0..31.
class _Counting implements Random {
  int _next = 0;

  @override
  int nextInt(int max) => _next++ % max;

  @override
  bool nextBool() => throw UnimplementedError();

  @override
  double nextDouble() => throw UnimplementedError();
}

// Same vector as worker/test/worker.test.ts.
const _token = 'AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8';
const _writeKey = 'tMrBM5qB69WTm8WzD7fYD_RObHxyM008lQJ1tWeXza8';
const _feedId = 'YQArYaWZInSbfkKswxD5i5hniSAVzwIqs6j7wchWkog';

void main() {
  test('derives the same keys as the worker', () {
    final token = ShareToken.generate(_Counting());
    expect(token.value, _token);
    expect(token.writeKey, _writeKey);
    expect(token.feedId, _feedId);
    expect(ShareToken.tryParse(_token)!.feedId, _feedId);
  });

  test('a new token is 256 random bits, different every time', () {
    final tokens = {for (var i = 0; i < 50; i++) ShareToken.generate().value};
    expect(tokens, hasLength(50));
    for (final t in tokens) {
      expect(t, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
      expect(ShareToken.tryParse(t), isNotNull);
    }
  });

  test('the URL id never reveals the token or the write key', () {
    final token = ShareToken.generate();
    expect(token.feedId, isNot(token.value));
    expect(token.feedId, isNot(token.writeKey));
    expect(token.writeKey, isNot(token.value));
    expect(token.toString(), isNot(contains(token.value)));
    expect(token.toString(), isNot(contains(token.writeKey)));
  });

  test('a damaged stored token is no token', () {
    expect(ShareToken.tryParse(null), isNull);
    expect(ShareToken.tryParse(''), isNull);
    expect(ShareToken.tryParse(_token.substring(1)), isNull);
    expect(ShareToken.tryParse('${_token}A'), isNull);
    expect(ShareToken.tryParse(_token.replaceFirst('A', '+')), isNull);
    expect(ShareToken.tryParse('${_token.substring(0, 42)}='), isNull);
  });

  test('the link settings never go into a backup', () {
    for (final key in ShareLinkKeys.all) {
      expect(isDeviceSetting(key), isTrue, reason: key);
    }
    expect(isDeviceSetting('calendars.active'), isFalse);
  });

  group('SHARE_LINK_BASE_URL', () {
    test('empty means the feature is off', () {
      expect(AppConfig.parseShareLinkBase(''), isNull);
      expect(const AppConfig(shareLinkBaseUrl: '').shareLinkBase, isNull);
    });

    test('only a plain https base is accepted', () {
      expect(
        AppConfig.parseShareLinkBase('https://share.example.com/'),
        Uri.parse('https://share.example.com'),
      );
      expect(
        AppConfig.parseShareLinkBase('https://example.com/turnly'),
        Uri.parse('https://example.com/turnly'),
      );
      expect(AppConfig.parseShareLinkBase('http://share.example.com'), isNull);
      expect(AppConfig.parseShareLinkBase('https://a.com/?x=1'), isNull);
      expect(AppConfig.parseShareLinkBase('https://a.com/#x'), isNull);
      expect(AppConfig.parseShareLinkBase('https://u:p@a.com'), isNull);
      expect(AppConfig.parseShareLinkBase('webcal://a.com'), isNull);
      expect(AppConfig.parseShareLinkBase('not a url'), isNull);
    });
  });
}
