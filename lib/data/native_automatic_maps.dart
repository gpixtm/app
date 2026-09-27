import '../domain/app_message.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:maplibre_gl/maplibre_gl.dart' as native;

import '../domain/automatic_maps.dart';

/// MapLibre owns the durable tile/style/font/sprite database. Our small account
/// file records the intended areas so interrupted preparation resumes at launch.
class NativeAutomaticMaps implements AutomaticMapStore {
  NativeAutomaticMaps(this.directory);
  final Directory directory;
  final _regions = <String, native.OfflineRegion>{};
  bool _closed = false;
  int? _active;
  Future<void>? _operation;
  @override
  String get style => 'https://tiles.openfreemap.org/styles/liberty';
  File get _manifest => File('${directory.path}/automatic-areas.json');

  @override
  Future<List<StoredMapArea>> restore() async {
    await directory.create(recursive: true);
    await native.setOfflineMaxConcurrentRequests(maxRequests: 4);
    for (final r in await native.getListOfRegions()) {
      if (r.definition.mapStyleUrl == style &&
          r.metadata['gpix-area'] is String) {
        _regions[r.metadata['gpix-area'] as String] = r;
      }
    }
    final keys = await _manifest.exists()
        ? (jsonDecode(await _manifest.readAsString()) as List).cast<String>()
        : <String>[];
    final result = <StoredMapArea>[];
    for (final key in keys) {
      final area = MapArea.parse(key), region = _regions[key];
      final ready =
          region != null &&
          (await native.getOfflineRegionStatus(region.id)).isComplete;
      result.add(StoredMapArea(area, ready));
    }
    return result;
  }

  @override
  Future<void> remember(List<MapArea> areas) async {
    await directory.create(recursive: true);
    final temp = File('${_manifest.path}.part');
    await temp.writeAsString(
      jsonEncode(areas.map((a) => a.key).toList()),
      flush: true,
    );
    await temp.rename(_manifest.path);
  }

  @override
  Future<void> download(MapArea area, void Function(double) progress) {
    final work = _download(area, progress);
    _operation = work;
    return work;
  }

  Future<void> _download(MapArea area, void Function(double) progress) async {
    if (_closed) throw MessageFailure(AppMessage.libraryClosed);
    final previous = _regions[area.key];
    if (previous != null &&
        (await native.getOfflineRegionStatus(previous.id)).isComplete) {
      return;
    }
    if (previous != null) await native.deleteOfflineRegion(previous.id);
    final b = area.bounds;
    // Native tile enumeration uses inclusive bounds. Keep the requested
    // rectangle just inside its grid cell to avoid floating-point edge tiles.
    const inset = 0.0000001;
    final region = await native.downloadOfflineRegion(
      native.OfflineRegionDefinition(
        bounds: native.LatLngBounds(
          southwest: native.LatLng(b.south + inset, b.west + inset),
          northeast: native.LatLng(b.north - inset, b.east - inset),
        ),
        mapStyleUrl: style,
        minZoom: 0,
        maxZoom: area.maxZoom.toDouble(),
      ),
      metadata: {'gpix-area': area.key},
    );
    _regions[area.key] = region;
    _active = region.id;
    var lastChange = DateTime.now(), count = -1;
    try {
      while (!_closed) {
        final status = await native.getOfflineRegionStatus(region.id);
        progress((status.downloadProgress / 100).clamp(0, 1));
        if (status.isComplete) return;
        if (count != status.completedResourceCount) {
          count = status.completedResourceCount;
          lastChange = DateTime.now();
        }
        if (DateTime.now().difference(lastChange).inSeconds > 45) {
          throw SocketException('Download stalled');
        }
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      throw MessageFailure(AppMessage.libraryClosed);
    } finally {
      await native.pauseOfflineRegionDownload(region.id);
      _active = null;
    }
  }

  @override
  Future<void> close() async {
    _closed = true;
    final active = _active;
    if (active != null) await native.pauseOfflineRegionDownload(active);
    try {
      await _operation;
    } catch (_) {}
  }
}
