import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpix/application/app_controller.dart';
import 'package:gpix/application/library.dart';
import 'package:gpix/data/trail_codec.dart';
import 'package:gpix/presentation/history.dart';
import 'package:gpix/presentation/localization.dart';

import 'lifecycle_test.dart' show Repository, Maps, Gps, Elevation, Sync;
import 'route_history_test.dart' show eastward, straight, walkAlong;

Future<AppController> _threeWalks() async {
  final repository = Repository();
  final app = AppController(
    library: Library(repository, XmlGpxDecoder(), Elevation()),
    maps: Maps(),
    gps: Gps(),
    sync: Sync(),
    setAwake: (_) async {},
    vibrate: () async {},
  );
  await repository.save(straight);
  for (final (id, speed, day) in [
    ('a', 1.4, 1),
    ('b', 1.1, 8),
    ('c', 1.3, 15),
  ]) {
    await repository.save(
      walkAlong(
        id,
        eastward(0, 2000),
        speed: speed,
        sourceTrailId: 'route',
        started: DateTime(2026, 9, day, 9),
      ),
    );
  }
  await repository.save(
    walkAlong('lone', eastward(0, 300), started: DateTime(2026, 9, 10)),
  );
  await app.reload();
  return app;
}

void main() {
  for (final language in ['en', 'fr']) {
    testWidgets('history lists each route once and opens its walks, '
        'comparison and progress ($language)', (tester) async {
      tester.view.physicalSize = const Size(412, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final l10n = lookupAppLocalizations(Locale(language));
      final app = await _threeWalks();
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            // The app shell rebuilds its pages on every controller change.
            body: StreamBuilder<void>(
              stream: app.changes.stream,
              builder: (_, _) =>
                  HistoryView(app, openMap: () {}, openSettings: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Four walks, two entries: the route walked three times comes first.
      expect(find.byType(RouteHistoryCard), findsNWidgets(2));
      expect(find.text('Straight'), findsOneWidget);
      final context = tester.element(find.byType(HistoryView));
      expect(
        find.text(
          l10n.routeLastWalked(shortDate(context, DateTime(2026, 9, 15)), 3),
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          l10n.bestPerformance(
            speedLabel(1.4 * 3.6),
            shortDate(context, DateTime(2026, 9, 1)),
          ),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Straight'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.walkTab), findsOneWidget);
      expect(find.text(l10n.recordFastest), findsNothing);

      // The oldest walk is the fastest.
      await tester.tap(find.text(shortDate(context, DateTime(2026, 9, 1))));
      await tester.pumpAndSettle();
      expect(find.text(l10n.recordFastest), findsOneWidget);

      await tester.tap(find.text(l10n.compareTab));
      await tester.pumpAndSettle();
      expect(find.text(l10n.aheadBehindTitle), findsOneWidget);
      // Latest (1.3 m/s) against the record (1.4 m/s): A ends about 110 s
      // behind.
      final suffix = l10n.gapBehind('#', '#').split('#').last;
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              (w.data?.endsWith(suffix) ?? false) &&
              RegExp(r'1 min [45]\d s').hasMatch(w.data!),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text(l10n.progressTab));
      await tester.pumpAndSettle();
      expect(find.text(l10n.speedProgressTitle), findsOneWidget);
      expect(find.text(l10n.records), findsOneWidget);

      await tester.tap(find.byType(PopupMenuButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.deleteAllWalks));
      await tester.pumpAndSettle();
      expect(find.text(l10n.deleteAllWalksQuestion(3)), findsOneWidget);
      await tester.tap(find.text(l10n.delete));
      await tester.pumpAndSettle();

      // The walks are gone, the route stays, and history is back on screen.
      expect(app.history.map((t) => t.id), ['lone']);
      expect(app.trails.map((t) => t.id), ['route']);
      expect(find.byType(RouteHistoryCard), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      app.dispose();
    });
  }
}
