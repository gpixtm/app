import 'localization.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/app_controller.dart';
import '../domain/models.dart';

Future<void> openDirectionsLink(BuildContext context, Uri uri) async {
  try {
    await const MethodChannel('gpix/navigation')
        .invokeMethod<void>('open', {'url': uri.toString()});
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.cannotOpenNavigation)),
      );
    }
  }
}

Future<void> showJoinTrail(
  BuildContext context,
  AppController app,
  Trail trail,
) async {
  final reverse =
      app.selected?.id == trail.id &&
      (app.approach != null
          ? app.approachReverse
          : app.session?.reverse == true);
  final mode = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.joinTrail,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                context.l10n.nearestJoinInfo,
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '${trail.name}${reverse ? context.l10n.reverseSuffix : ''}',
                textAlign: TextAlign.center,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.hiking),
              title: Text(context.l10n.walkInGpix),
              subtitle: Text(context.l10n.onlineRouteInfo),
              enabled: app.approachSource != null,
              onTap: () => Navigator.pop(context, 'gpix'),
            ),
            ListTile(
              leading: const Icon(Icons.directions_walk),
              title: Text(context.l10n.walkInGoogleMaps),
              onTap: () => Navigator.pop(context, 'walking'),
            ),
            ListTile(
              leading: const Icon(Icons.directions_car),
              title: Text(context.l10n.driveInGoogleMaps),
              onTap: () => Navigator.pop(context, 'driving'),
            ),
            Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                context.l10n.routingPrivacy,
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  if (mode == null || !context.mounted) return;
  if (mode == 'gpix') {
    await app.joinTrail(trail, reverse: reverse);
  } else {
    final end = await app.closestJoinPoint(trail);
    if (end == null || !context.mounted) return;
    await openDirectionsLink(
      context,
      Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'destination': '${end.lat},${end.lon}',
        'travelmode': mode,
        'dir_action': 'navigate',
      }),
    );
  }
}
