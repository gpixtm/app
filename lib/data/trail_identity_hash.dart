import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../domain/models.dart';
import '../domain/trail_identity.dart';

/// Namespace of name-based public trail identifiers, shared with the API
/// (`App\Domain\TrailFingerprint::NAMESPACE`).
const sharedTrailNamespace = '8f5c2a61-3b7e-4d9a-a1c4-6e0b9d2f7a35';

/// SHA-256 fingerprint and version 5 identifier, as computed by the API.
class HashedTrailIdentity implements TrailIdentity {
  const HashedTrailIdentity();
  @override
  String? fingerprint(Iterable<List<GeoPoint>> segments) {
    final text = trailIdentityText(segments);
    return text == null ? null : sha256.convert(utf8.encode(text)).toString();
  }

  @override
  String sharedId(String fingerprint) =>
      const Uuid().v5(sharedTrailNamespace, fingerprint);
}
