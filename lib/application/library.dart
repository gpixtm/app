import 'dart:isolate';

import '../domain/models.dart';
import '../domain/ports.dart';

class Library {
  const Library(this.repository, this.decoder, this.elevation);
  final TrailRepository repository;
  final GpxDecoder decoder;
  final ElevationSource elevation;
  Future<List<Trail>> import(String xml, String filename) async {
    final parser = decoder;
    final trails = await Isolate.run(() => parser.decode(xml, filename));
    for (final trail in trails) {
      await repository.save(trail);
    }
    return trails;
  }

  Future<void> prepareProfile(Trail trail) async =>
      repository.save(await elevation.complete(trail));
}
