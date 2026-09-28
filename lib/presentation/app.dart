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
import 'attach_points.dart';
import 'catalogue_view.dart';
import 'map_workspace.dart';
import 'history.dart';
import 'settings.dart';

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

/// The map is the home screen; the menu opens every other page over it.
enum Screen { map, catalogue, trails, history, offline, settings }

class _HomeState extends State<Home> with WidgetsBindingObserver {
  Screen page = Screen.map;
  String trailQuery = '';

  /// The library lists only the points files not attached to a trail.
  bool onlyPointsFiles = false;
  AppController get app => widget.app;
  void open(Screen value) => setState(() => page = value);
  void showOnMap(Trail trail) {
    app.focus(trail);
    open(Screen.map);
  }

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

  /// Import the GPX files chosen together. Points files among them are
  /// previewed on the map, attached to [attachTo] or to the best trail.
  Future<void> import({Trail? attachTo}) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gpx'],
      );
      final files = <(String, String)>[];
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
        files.add((text, name));
      }
      if (files.isEmpty) return;
      await app.importFiles(files, attachTo: attachTo);
      if (app.attaching != null) open(Screen.map);
    } catch (e) {
      await app.run(() async => throw e);
    }
  }

  /// Preview attaching a points file of the library to its best trail.
  Future<void> attach(Trail file) async {
    await app.beginAttachment([file]);
    if (app.attaching != null) open(Screen.map);
  }

  Future<void> addPoints(Trail trail) async {
    final started = await addPointsTo(
      context,
      app,
      trail,
      importFromPhone: (target) => import(attachTo: target),
    );
    if (started) open(Screen.map);
  }

  void settings() => open(Screen.settings);
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

  String title(BuildContext context) => switch (page) {
    Screen.map => context.l10n.map,
    Screen.catalogue => context.l10n.allTrails,
    Screen.trails => context.l10n.myTrails,
    Screen.history => context.l10n.history,
    Screen.offline => context.l10n.offline,
    Screen.settings => context.l10n.settings,
  };

  Widget menu(BuildContext context) => NavigationDrawer(
    selectedIndex: page.index,
    onDestinationSelected: (index) {
      Navigator.of(context).pop();
      open(Screen.values[index]);
    },
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(28, 20, 16, 16),
        child: Row(
          children: const [
            Icon(Icons.terrain, color: forest, size: 30),
            SizedBox(width: 8),
            Text(
              'gpix',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
          ],
        ),
      ),
      NavigationDrawerDestination(
        icon: const Icon(Icons.map_outlined),
        selectedIcon: const Icon(Icons.map),
        label: Text(context.l10n.map),
      ),
      NavigationDrawerDestination(
        icon: const Icon(Icons.travel_explore_outlined),
        selectedIcon: const Icon(Icons.travel_explore),
        label: Text(context.l10n.allTrails),
      ),
      NavigationDrawerDestination(
        icon: const Icon(Icons.route_outlined),
        selectedIcon: const Icon(Icons.route),
        label: Text(context.l10n.myTrails),
      ),
      NavigationDrawerDestination(
        icon: const Icon(Icons.history),
        label: Text(context.l10n.history),
      ),
      NavigationDrawerDestination(
        icon: const Icon(Icons.download_for_offline_outlined),
        selectedIcon: const Icon(Icons.download_for_offline),
        label: Text(context.l10n.offline),
      ),
      NavigationDrawerDestination(
        icon: const Icon(Icons.settings_outlined),
        selectedIcon: const Icon(Icons.settings),
        label: Text(context.l10n.settings),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => StreamBuilder<void>(
    stream: app.changes.stream,
    builder: (context, _) => PopScope(
      // System back returns from any page to the map.
      canPop: page == Screen.map,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) open(Screen.map);
      },
      child: Scaffold(
        drawer: menu(context),
        appBar: page == Screen.map
            ? null
            : AppBar(
                leading: IconButton(
                  tooltip: context.l10n.backToMap,
                  onPressed: () => open(Screen.map),
                  icon: const Icon(Icons.arrow_back),
                ),
                title: Text(title(context)),
                actions: [
                  if (page == Screen.trails)
                    IconButton(
                      tooltip: context.l10n.sync,
                      onPressed: app.busy ? null : app.synchronize,
                      icon: const Icon(Icons.sync),
                    ),
                ],
              ),
        body: SafeArea(
          child: Column(
            children: [
              if (app.connectionDetails?.call().problem
                  case final String problem)
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
                          child: Text(
                            context.message(app.message!),
                            maxLines: 4,
                          ),
                        ),
                        if (app.message case AppMessage(code: 'pointsAttached')
                            when app.lastAttachment != null)
                          TextButton(
                            onPressed: app.busy ? null : app.undoAttachment,
                            child: Text(context.l10n.undo),
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
                // Keep the map alive underneath the other pages.
                child: IndexedStack(
                  index: page.index,
                  children: [
                    MapWorkspace(
                      app,
                      mapBuilder: widget.mapBuilder,
                      openLibrary: () => open(Screen.trails),
                      importTrails: import,
                    ),
                    CatalogueView(app, showMap: () => open(Screen.map)),
                    libraryView(context),
                    HistoryView(
                      app,
                      openMap: () => open(Screen.map),
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
      ),
    ),
  );

  Widget libraryView(BuildContext context) {
    final query = foldForSearch(trailQuery.trim());
    final pointsFiles = app.pointsFiles;
    final onlyPoints = onlyPointsFiles && pointsFiles.isNotEmpty;
    final shown = [
      for (final trail in onlyPoints ? pointsFiles : app.trails)
        if (query.isEmpty || foldForSearch(trail.name).contains(query)) trail,
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        TextField(
          onChanged: (value) => setState(() => trailQuery = value),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: context.l10n.searchTrails,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: Text(context.l10n.itemCount(app.trails.length))),
            FilledButton.tonalIcon(
              onPressed: app.busy ? null : import,
              icon: const Icon(Icons.add),
              label: Text(context.l10n.importGpx),
            ),
          ],
        ),
        if (app.trails.isEmpty && app.loadDemo != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: app.busy ? null : app.demonstrate,
              child: Text(context.l10n.tryDemo),
            ),
          ),
        Text(
          context.l10n.sharingNotice,
          style: const TextStyle(fontSize: 12, color: Color(0xff627068)),
        ),
        const SizedBox(height: 12),
        // Points files are not shown with any trail until they are attached.
        if (pointsFiles.isNotEmpty && app.collaborative != null)
          Card(
            color: const Color(0xffffedcd),
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const Icon(
                Icons.wrong_location_outlined,
                color: Color(0xff6b4b14),
              ),
              title: Text(
                context.l10n.pointsFilesBanner(pointsFiles.length),
                style: const TextStyle(fontSize: 14),
              ),
              trailing: TextButton(
                onPressed: () => setState(() => onlyPointsFiles = !onlyPoints),
                child: Text(
                  onlyPoints
                      ? context.l10n.showAllItems
                      : context.l10n.showPointsFiles,
                ),
              ),
            ),
          ),
        if (app.trails.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(context.l10n.importIntro, textAlign: TextAlign.center),
          )
        else if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              context.l10n.noTrailMatch(trailQuery.trim()),
              textAlign: TextAlign.center,
            ),
          ),
        for (final trail in shown) trailCard(context, trail),
      ],
    );
  }

  Widget trailCard(BuildContext context, Trail trail) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => showOnMap(trail),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  trail.followable ? Icons.route : Icons.place_outlined,
                  color: forest,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    trail.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (choice) => choice == 'points'
                      ? addPoints(trail)
                      : confirmDelete(trail),
                  itemBuilder: (_) => [
                    if (trail.followable && app.collaborative != null)
                      PopupMenuItem(
                        value: 'points',
                        child: Text(context.l10n.addPoints),
                      ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(context.l10n.delete),
                    ),
                  ],
                ),
              ],
            ),
            Text(
              trail.followable
                  ? [
                      context.l10n.segmentCount(
                        kilometers(TrailGeometry(trail).total),
                        trail.segments.length,
                      ),
                      if (app.placeCount(trail) case final count when count > 0)
                        context.l10n.trailPlaceCount(count),
                    ].join(' · ')
                  : context.l10n.pointCount(trail.pois.length),
            ),
            const SizedBox(height: 8),
            StatusPill(
              trail.followable
                  ? (app.covers(trail)
                        ? context.l10n.mapReady
                        : context.l10n.mapNeedsPreparation)
                  : context.l10n.pointsFileNotAttached,
              good: trail.followable && app.covers(trail),
            ),
            if (app.isOfflineCopy(trail))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  context.l10n.catalogueTrailKeptOffline,
                  style: const TextStyle(fontSize: 12, color: catalogueColor),
                ),
              ),
            Wrap(
              spacing: 4,
              children: [
                TextButton.icon(
                  onPressed: () => showOnMap(trail),
                  icon: const Icon(Icons.center_focus_strong),
                  label: Text(context.l10n.view),
                ),
                if (!trail.followable && app.collaborative != null)
                  TextButton.icon(
                    onPressed: app.busy ? null : () => attach(trail),
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: Text(context.l10n.attachToTrail),
                  ),
                if (trail.followable) ...[
                  TextButton.icon(
                    onPressed: app.busy
                        ? null
                        : () {
                            app.beginPlanning(trail);
                            open(Screen.map);
                          },
                    icon: const Icon(Icons.edit_road),
                    label: Text(context.l10n.days),
                  ),
                  TextButton.icon(
                    onPressed: app.busy
                        ? null
                        : () async {
                            showOnMap(trail);
                            await app.launch(trail);
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
  );
  Future<void> confirmDelete(Trail t) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(context.l10n.deleteItemQuestion),
        content: Text(
          t.followable
              ? context.l10n.removeSharedTrailBody
              : context.l10n.deleteItemBody,
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
    if (yes == true) await app.removeTrail(t);
  }

  Widget offlineView(BuildContext context) => ListView(
    padding: const EdgeInsets.all(22),
    children: [
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
