import 'localization.dart';

import 'package:flutter/material.dart';

import '../application/app_controller.dart';
import 'finish_route_dialog.dart';

/// Whether the recording in progress will become a route when finished.
bool recordingRoute(AppController app) =>
    app.recorder?.current?.saved.walk?.sourceTrailId == null;

Future<void> confirmFinishWalk(BuildContext context, AppController app) async {
  // A free walk becomes a route the walker names before it is shared.
  if (recordingRoute(app)) {
    final started = app.recorder?.current?.saved.walk?.started;
    final details = await showDialog<RouteDetails>(
      context: context,
      builder: (_) => FinishRouteDialog(
        suggestedName: started == null
            ? ''
            : context.l10n.walkedRouteName(started),
      ),
    );
    if (details != null) {
      await app.finishWalk(
        name: details.name,
        description: details.description,
      );
    }
    return;
  }
  final yes = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(context.l10n.finishWalkQuestion),
      content: Text(context.l10n.finishWalkInfo),
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

/// Whether the walk is being recorded or paused, and any recording error.
class RecordingStatus extends StatelessWidget {
  const RecordingStatus(this.app, {super.key});
  final AppController app;
  @override
  Widget build(BuildContext context) {
    final active = app.recorder?.active == true;
    final error = app.recorder?.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          active ? context.l10n.recordingActive : context.l10n.walkPaused,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: active ? const Color(0xffc62828) : const Color(0xff627068),
          ),
        ),
        if (error != null)
          Text(
            context.message(error),
            style: const TextStyle(color: Colors.deepOrange),
          ),
      ],
    );
  }
}
