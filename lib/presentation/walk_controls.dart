import 'localization.dart';

import 'package:flutter/material.dart';

import '../application/app_controller.dart';

/// Whether the recording in progress will become a route when finished.
bool recordingRoute(AppController app) =>
    app.recorder?.current?.saved.walk?.sourceTrailId == null;

Future<void> confirmFinishWalk(BuildContext context, AppController app) async {
  final route = recordingRoute(app);
  final yes = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(
        route
            ? context.l10n.finishRouteQuestion
            : context.l10n.finishWalkQuestion,
      ),
      content: Text(
        route ? context.l10n.finishRouteInfo : context.l10n.finishWalkInfo,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: Text(context.l10n.continueAction),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, true),
          child: Text(context.l10n.saveWalk),
        ),
      ],
    ),
  );
  if (yes == true) await app.finishWalk();
}

/// Pause or resume, then finish, the recording in progress.
class WalkControls extends StatelessWidget {
  const WalkControls(this.app, {super.key});
  final AppController app;
  @override
  Widget build(BuildContext context) {
    final active = app.recorder?.active == true;
    return Wrap(
      spacing: 8,
      children: [
        FilledButton.icon(
          onPressed: app.busy ? null : (active ? app.pauseWalk : app.freeWalk),
          icon: Icon(active ? Icons.pause : Icons.play_arrow),
          label: Text(active ? context.l10n.pause : context.l10n.resume),
        ),
        OutlinedButton.icon(
          onPressed: app.busy ? null : () => confirmFinishWalk(context, app),
          icon: const Icon(Icons.flag_outlined),
          label: Text(
            recordingRoute(app)
                ? context.l10n.finishRoute
                : context.l10n.finish,
          ),
        ),
      ],
    );
  }
}
