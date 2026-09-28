import 'dart:isolate';

import '../domain/models.dart';
import '../domain/ports.dart';
import '../domain/shared_trails.dart';
import '../domain/trail_identity.dart';

/// Imported trails, and how many of them already existed.
class ImportResult {
  const ImportResult(this.trails, this.reused);
  final List<Trail> trails;
  final int reused;
}

class Library {
  const Library(
    this.repository,
    this.decoder,
    this.elevation, {
    this.shared,
    this.identity,
  });
  final TrailRepository repository;
  final GpxDecoder decoder;
  final ElevationSource elevation;

  /// Offline catalogue used to recognise a line another walker already shared.
  final SharedTrailStore? shared;

  /// Without it (tests, demo), trails keep the decoder identifiers.
  final TrailIdentity? identity;

  /// A line already in the library or already shared is reused, never
  /// duplicated. A new line takes the identifier every phone derives from its
  /// geometry, so the same GPX imported on another phone meets it again.
  Future<ImportResult> import(String xml, String filename) async {
    final parser = decoder;
    final decoded = await Isolate.run(() => parser.decode(xml, filename));
    final known = <String, Trail>{};
    for (final t in await repository.all()) {
      if (t.walk != null) continue;
      final fingerprint = identity?.fingerprint(t.segments);
      if (fingerprint != null) known[fingerprint] = t;
    }
    final catalogue = {
      for (final s in await shared?.all() ?? const <SharedTrail>[])
        s.fingerprint: s,
    };
    final result = <Trail>[];
    var reused = 0;
    for (final trail in decoded) {
      final fingerprint = identity?.fingerprint(trail.segments);
      if (fingerprint == null) {
        await repository.save(trail);
        result.add(trail);
        continue;
      }
      if (known[fingerprint] case final existing?) {
        reused++;
        result.add(existing);
        continue;
      }
      final Trail kept;
      if (catalogue[fingerprint] case final shared?) {
        reused++;
        kept = _identified(trail, shared.id, name: shared.name);
      } else {
        kept = _identified(trail, identity!.sharedId(fingerprint));
      }
      await repository.save(kept);
      known[fingerprint] = kept;
      result.add(kept);
    }
    return ImportResult(result, reused);
  }

  static Trail _identified(Trail trail, String id, {String? name}) => Trail(
    id: id,
    name: name ?? trail.name,
    segments: trail.segments,
    pois: trail.pois,
    description: trail.description,
    estimated: trail.estimated,
    days: trail.days,
    walk: trail.walk,
    publicId: id,
  );

  Future<void> prepareProfile(Trail trail) async =>
      repository.save(await elevation.complete(trail));
}
