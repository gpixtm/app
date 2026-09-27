import 'localization.dart';
import 'import_name_dialog.dart';
import '../data/gpx_text.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../domain/ports.dart';
import '../domain/trail_geometry.dart';
import '../application/app_controller.dart';
import 'design.dart';
import 'auth.dart';
import '../application/auth_controller.dart';
import 'map_workspace.dart';
import 'history.dart';
import 'settings.dart';
import 'join_departure.dart';

class GpixApp extends StatelessWidget {
  const GpixApp(this.controller, {this.mapBuilder, super.key});
  final Widget Function(AppController)? mapBuilder;
  final AppController controller;
  @override
  Widget build(BuildContext context) => LocalizedApp(
    theme: appTheme(),
    homeBuilder: (context) => Home(controller, mapBuilder: mapBuilder),
  );
}

class Home extends StatefulWidget {
  const Home(this.app, {this.auth, this.mapBuilder, super.key});
  final Widget Function(AppController)? mapBuilder;
  final AppController app;
  final AuthController? auth;
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  int tab = 1;
  AppController get app => widget.app;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      app.lifecycle(state == AppLifecycleState.resumed);
  Future<void> import() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gpx'],
      );
      for (final file in result) {
        if ((await file.length() ?? 0) > 50 * 1024 * 1024) {
          throw MessageFormatException(AppMessage.gpxSizeLimit);
        }
        final text = decodeGpxBytes(await file.readAsBytes());
        var name = file.name.replaceFirst(
          RegExp(r'\.gpx$', caseSensitive: false),
          '',
        );
        if (damagedText(name)) {
          if (!mounted) return;
          final corrected = await showDialog<String>(
            context: context,
            builder: (_) => const ImportNameDialog(),
          );
          if (corrected == null) continue;
          name = corrected;
        }
        await app.import(text, name);
      }
    } catch (e) {
      await app.run(() async => throw e);
    }
  }

  void settings() => setState(() => tab = 4);
  Future<void> accountSettings() async {
    final auth = widget.auth;
    if (auth == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AccountScreen(
          auth: auth,
          resolveConflicts: () async {
            await app.run(() async {
              await app.sync.resolveConflicts();
              await app.reload();
            });
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<void>(
    stream: app.changes.stream,
    builder: (context, _) => Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (app.connectionDetails?.call().problem case final String problem)
              Material(
                color: const Color(0xffffedcd),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          problem,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      TextButton(
                        onPressed: settings,
                        child: Text(context.l10n.settings),
                      ),
                    ],
                  ),
                ),
              ),
            if (app.busy)
              LinearProgressIndicator(value: app.progress, minHeight: 3),
            if (app.message != null)
              Material(
                color: const Color(0xffe6ecdf),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(context.message(app.message!), maxLines: 4),
                      ),
                      IconButton(
                        onPressed: () => setState(() => app.message = null),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: IndexedStack(
                index: tab,
                children: [
                  libraryView(context),
                  MapWorkspace(
                    app,
                    mapBuilder: widget.mapBuilder,
                    openLibrary: () => setState(() => tab = 0),
                    openHistory: () => setState(() => tab = 2),
                  ),
                  HistoryView(
                    app,
                    openMap: () => setState(() => tab = 1),
                    openSettings: settings,
                  ),
                  offlineView(context),
                  SettingsView(app, account: accountSettings),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (v) => setState(() => tab = v),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route),
            label: context.l10n.myTrails,
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: context.l10n.map,
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: context.l10n.history,
          ),
          NavigationDestination(
            icon: Icon(Icons.download_for_offline_outlined),
            selectedIcon: Icon(Icons.download_for_offline),
            label: context.l10n.offline,
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: context.l10n.settings,
          ),
        ],
      ),
    ),
  );
  Widget libraryView(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
    children: [
      Row(
        children: [
          const Icon(Icons.terrain, color: forest, size: 30),
          const SizedBox(width: 8),
          const Text(
            'gpix',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: context.l10n.sync,
            onPressed: app.busy ? null : app.synchronize,
            icon: const Icon(Icons.sync),
          ),
          IconButton(
            tooltip: context.l10n.settings,
            onPressed: settings,
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      const SizedBox(height: 28),
      Text(
        context.l10n.joyOfWalking,
        style: TextStyle(
          color: forest,
          fontSize: 11,
          letterSpacing: 2,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        context.l10n.nextTrailStartsHere,
        style: Theme.of(context).textTheme.headlineLarge,
      ),
      const SizedBox(height: 14),
      Text(
        context.l10n.libraryIntro,
        style: TextStyle(fontSize: 16, color: Color(0xff627068), height: 1.5),
      ),
      const SizedBox(height: 24),
      FilledButton.icon(
        onPressed: app.busy ? null : import,
        icon: const Icon(Icons.add),
        label: Text(context.l10n.importGpx),
      ),
      if (app.trails.isEmpty && app.loadDemo != null)
        TextButton(
          onPressed: app.busy ? null : app.demonstrate,
          child: Text(context.l10n.tryDemo),
        ),
      const SizedBox(height: 32),
      Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.myLibrary,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const SizedBox(width: 10),
          Text(context.l10n.itemCount(app.trails.length)),
        ],
      ),
      const SizedBox(height: 14),
      if (app.trails.isEmpty)
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: const Color(0xffe9eee2),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              Icon(Icons.hiking, size: 60, color: forest),
              SizedBox(height: 18),
              Text(
                context.l10n.oneJourney,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 10),
              Text(
                context.l10n.importIntro,
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.5),
              ),
            ],
          ),
        ),
      for (final trail in app.trails)
        Card(
          margin: const EdgeInsets.only(bottom: 14),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () {
              app.focus(trail);
              setState(() => tab = 1);
            },
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xffedf1e7),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          trail.followable ? Icons.route : Icons.place_outlined,
                          color: forest,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          trail.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (_) => confirmDelete(trail),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(context.l10n.delete),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    trail.followable
                        ? context.l10n.segmentCount(
                            kilometers(TrailGeometry(trail).total),
                            trail.segments.length,
                          )
                        : context.l10n.pointCount(trail.pois.length),
                  ),
                  const SizedBox(height: 12),
                  StatusPill(
                    trail.followable
                        ? (app.covers(trail)
                              ? context.l10n.mapReady
                              : context.l10n.mapNeedsPreparation)
                        : context.l10n.savedPlaces,
                    good: !trail.followable || app.covers(trail),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          app.focus(trail);
                          setState(() => tab = 1);
                        },
                        icon: const Icon(Icons.center_focus_strong),
                        label: Text(context.l10n.view),
                      ),
                      if (trail.followable) ...[
                        TextButton.icon(
                          onPressed: app.busy
                              ? null
                              : () async {
                                  setState(() => tab = 1);
                                  app.focus(trail);
                                  await showJoinTrail(context, app, trail);
                                },
                          icon: const Icon(Icons.directions_walk),
                          label: Text(context.l10n.joinTrail),
                        ),
                        TextButton.icon(
                          onPressed: app.busy
                              ? null
                              : () {
                                  app.beginPlanning(trail);
                                  setState(() => tab = 1);
                                },
                          icon: const Icon(Icons.edit_road),
                          label: Text(context.l10n.days),
                        ),
                        FilledButton.icon(
                          onPressed: app.busy
                              ? null
                              : () async {
                                  app.select(trail);
                                  setState(() => tab = 1);
                                  await app.start();
                                },
                          icon: const Icon(Icons.play_arrow),
                          label: Text(context.l10n.go),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
    ],
  );
  Future<void> confirmDelete(Trail t) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(context.l10n.deleteItemQuestion),
        content: Text(context.l10n.deleteItemBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(context.l10n.keep),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (yes == true) await app.removeTrail(t);
  }

  Widget offlineView(BuildContext context) => ListView(
    padding: const EdgeInsets.all(22),
    children: [
      const SizedBox(height: 16),
      Text(
        context.l10n.offlineHeadline,
        style: Theme.of(context).textTheme.headlineLarge,
      ),
      const SizedBox(height: 14),
      Text(
        context.l10n.sharedMaps,
        style: TextStyle(fontSize: 16, height: 1.5),
      ),
      const SizedBox(height: 22),
      if (app.automaticMaps != null) ...[
        Text(context.l10n.automaticMapsInfo),
        const SizedBox(height: 12),
        Text(context.message(app.mapStatus)),
        TextButton.icon(
          onPressed: app.automaticMaps!.retry,
          icon: const Icon(Icons.refresh),
          label: Text(context.l10n.resumePreparation),
        ),
        for (final trail in app.trails)
          ListTile(
            title: Text(trail.name),
            leading: Icon(
              app.covers(trail) ? Icons.offline_pin : Icons.downloading,
            ),
            subtitle: Text(
              app.covers(trail)
                  ? context.l10n.readyOffline
                  : context.l10n.preparingMaps,
            ),
          ),
        const Divider(),
      ],
      OutlinedButton.icon(
        onPressed: app.busy ? null : app.fetchCatalog,
        icon: const Icon(Icons.refresh),
        label: Text(context.l10n.loadCatalog),
      ),
      if (app.neededRegions.isNotEmpty)
        FilledButton.icon(
          onPressed: app.busy ? null : app.prepareAll,
          icon: const Icon(Icons.download),
          label: Text(
            context.l10n.prepareTrails(decimal(app.neededBytes / 1048576)),
          ),
        ),
      if (app.selected?.followable == true)
        TextButton.icon(
          onPressed: app.busy ? null : app.profile,
          icon: const Icon(Icons.landscape_outlined),
          label: Text(context.l10n.completeElevations),
        ),
      const SizedBox(height: 20),
      Text(
        context.l10n.onMyPhone,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      if (app.localMaps.isEmpty && app.automaticMaps == null)
        Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Text(context.l10n.noInstalledMaps),
        ),
      for (final m in app.localMaps)
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: const Icon(Icons.offline_pin, color: forest),
            title: Text(m.region.name),
            subtitle: Text(
              context.l10n.mapSizeVersion(
                decimal(m.region.bytes / 1048576),
                m.region.version,
              ),
            ),
            trailing: IconButton(
              tooltip: context.l10n.deleteMap,
              onPressed: app.busy ? null : () => removeMap(m),
              icon: const Icon(Icons.delete_outline),
            ),
          ),
        ),
      const SizedBox(height: 24),
      if (app.regions.isNotEmpty)
        Text(
          context.l10n.availableRegions,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      for (final r in app.regions)
        Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(r.name),
            subtitle: Text(
              context.l10n.mapSizeCoverage(
                decimal(r.bytes / 1048576),
                app.selected != null && app.regionCovers(r, app.selected!)
                    ? context.l10n.coversOpenTrail
                    : '',
              ),
            ),
            trailing: IconButton(
              tooltip: context.l10n.download,
              onPressed: app.busy ? null : () => app.download(r),
              icon: const Icon(Icons.download_outlined),
            ),
          ),
        ),
    ],
  );
  Future<void> removeMap(LocalMap m) async {
    final affected = app.affectedByRemoval(m).map((t) => t.name).join(', ');
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(context.l10n.removeMapQuestion),
        content: Text(
          context.l10n.affectedTrails(
            affected.isEmpty ? context.l10n.none : affected,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(context.l10n.keep),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (yes == true) await app.removeMap(m);
  }
}
