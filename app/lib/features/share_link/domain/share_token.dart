import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Bytes of a link secret: 256 bits from `Random.secure()`.
const int shareTokenBytes = 32;

/// Labels of the derivations. The worker uses the very same strings
/// (`worker/src/crypto.ts`); changing one breaks every published link.
const String shareWriteKeyLabel = 'turnly-share/v1/write';
const String shareFeedIdLabel = 'turnly-share/v1/feed:';

/// The secret behind one published link (docs/compartir.md, «Claves»).
///
/// - [value]: 32 random bytes, kept only on the phone (`settings`, never in
///   a backup file). Whoever holds it can update or delete the feed.
/// - [writeKey] = HMAC-SHA256([value], [shareWriteKeyLabel]): sent to the
///   worker with every upload and delete (header, over HTTPS), never shown.
/// - [feedId] = SHA-256([shareFeedIdLabel] ‖ writeKey): the only part in the
///   URL. Knowing it lets you read the feed, never write it: going back from
///   the id to the write key would mean inverting SHA-256.
///
/// The worker checks `SHA-256(label ‖ writeKey) == feedId` on every write,
/// so it needs no account, no table of keys and no first-come registration.
class ShareToken {
  ShareToken._(this.value, this._bytes);

  /// A new secret from [random] (`Random.secure()` unless a test passes
  /// another).
  factory ShareToken.generate([Random? random]) {
    final rng = random ?? Random.secure();
    final bytes = Uint8List(shareTokenBytes);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = rng.nextInt(256);
    }
    return ShareToken._(base64UrlNoPad(bytes), bytes);
  }

  /// The token stored as [text], or `null` when it is not one (wrong length
  /// or alphabet): a damaged setting never turns into a weaker secret.
  static ShareToken? tryParse(String? text) {
    if (text == null || !_tokenPattern.hasMatch(text)) return null;
    try {
      final bytes = base64Url.decode(base64.normalize(text));
      if (bytes.length != shareTokenBytes) return null;
      return ShareToken._(text, Uint8List.fromList(bytes));
    } catch (_) {
      return null;
    }
  }

  static final RegExp _tokenPattern = RegExp(r'^[A-Za-z0-9_-]{43}$');

  /// base64url without padding (43 characters).
  final String value;
  final Uint8List _bytes;

  late final List<int> _writeKeyBytes = Hmac(
    sha256,
    _bytes,
  ).convert(utf8.encode(shareWriteKeyLabel)).bytes;

  /// base64url (43 characters) of the write key.
  late final String writeKey = base64UrlNoPad(_writeKeyBytes);

  /// base64url (43 characters) of the public id that goes in the URL.
  late final String feedId = base64UrlNoPad(
    sha256.convert([...utf8.encode(shareFeedIdLabel), ..._writeKeyBytes]).bytes,
  );

  @override
  bool operator ==(Object other) => other is ShareToken && other.value == value;

  @override
  int get hashCode => value.hashCode;

  /// Never the secret: a token that ends up in a log says nothing.
  @override
  String toString() => 'ShareToken(…)';
}

String base64UrlNoPad(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');
