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

/// External fallback (driving, public transport…) towards the same nearest
/// joining point as the internal walking approach. Google Maps lets the
/// walker choose the travel mode.
Future<void> openInGoogleMaps(
  BuildContext context,
  AppController app,
  Trail trail,
) async {
  final end = await app.closestJoinPoint(trail);
  if (end == null || !context.mounted) return;
  await openDirectionsLink(
    context,
    Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${end.lat},${end.lon}',
    }),
  );
}
