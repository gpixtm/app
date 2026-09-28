import 'dart:async';

import 'package:flutter/material.dart';

import '../application/app_controller.dart';
import '../domain/catalogue.dart';
import '../domain/models.dart';
import '../domain/shared_trails.dart';
import 'design.dart';
import 'join_departure.dart' show openDirectionsLink;
import 'localization.dart';
import 'pin_images.dart';
import 'trail_details.dart';
import 'trail_reviews.dart';

/// Every trail of the application, searched on the server page by page:
/// groups first (the Ways of St James, itineraries such as the GR 20, the
/// walkers' collections), then trails. Nothing here is stored on the phone.
class CatalogueView extends StatefulWidget {
  const CatalogueView(this.app, {required this.showMap, super.key});
  final AppController app;

  /// Return to the map, where an opened trail is shown.
  final VoidCallback showMap;
  @override
  State<CatalogueView> createState() => _CatalogueViewState();
}

class _CatalogueViewState extends State<CatalogueView> {
  final query = TextEditingController();
  final scroll = ScrollController();
  List<CatalogueItem> items = [];
  String? next;
  bool loading = false, started = false;
  Object? error;
  Timer? debounce;
  int generation = 0;
  AppController get app => widget.app;

  @override
  void initState() {
    super.initState();
    scroll.addListener(() {
      if (scroll.position.extentAfter < 600) unawaited(more());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!started) {
      started = true;
      unawaited(search());
    }
  }

  @override
  void dispose() {
    debounce?.cancel();
    query.dispose();
    scroll.dispose();
    super.dispose();
  }

  void changed(String _) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 350), search);
  }

  /// A new query replaces the results; an older answer arriving late is
  /// ignored.
  Future<void> search() async {
    final request = ++generation;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final page = await app.searchCatalogue(query.text);
      if (!mounted || request != generation) return;
      app.noteSearchResults(page);
      setState(() {
        items = page.items;
        next = page.next;
      });
      if (scroll.hasClients) scroll.jumpTo(0);
    } catch (e) {
      if (mounted && request == generation) setState(() => error = e);
    } finally {
      if (mounted && request == generation) setState(() => loading = false);
    }
  }

  Future<void> more() async {
    final cursor = next;
    if (cursor == null || loading) return;
    final request = generation;
    setState(() => loading = true);
    try {
      final page = await app.searchCatalogue(query.text, cursor: cursor);
      if (!mounted || request != generation) return;
      app.noteSearchResults(page);
      setState(() {
        items = [...items, ...page.items];
        next = page.next;
      });
    } catch (e) {
      if (mounted && request == generation) setState(() => error = e);
    } finally {
      if (mounted && request == generation) setState(() => loading = false);
    }
  }

  Future<void> show(SharedTrail trail) async {
    await app.openShared(trail.id);
    if (mounted && app.focused?.sharedId == trail.id) widget.showMap();
  }

  @override
  Widget build(BuildContext context) => ListView.builder(
    controller: scroll,
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
    itemCount: items.length + 2,
    itemBuilder: (context, index) {
      if (index == 0) return header(context);
      if (index == items.length + 1) return footer(context);
      return switch (items[index - 1]) {
        CatalogueGroupItem(:final group) => GroupTile(
          group,
          onTap: () =>
              openGroup(context, app, group.id, showMap: widget.showMap),
        ),
        CatalogueTrailItem(:final trail) => CatalogueTrailTile(
          app,
          trail,
          onTap: app.busy ? null : () => show(trail),
        ),
      };
    },
  );

  Widget header(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        controller: query,
        onChanged: changed,
        onSubmitted: (_) => search(),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search),
          hintText: context.l10n.searchAllTrails,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
          isDense: true,
          suffixIcon: query.text.isEmpty
              ? null
              : IconButton(
                  tooltip: context.l10n.clearSearch,
                  onPressed: () {
                    query.clear();
                    unawaited(search());
                  },
                  icon: const Icon(Icons.close),
                ),
        ),
      ),
      const SizedBox(height: 8),
      const TrailColourLegend(),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: () => showMyGroups(context, app, showMap: widget.showMap),
          icon: const Icon(Icons.collections_bookmark_outlined),
          label: Text(context.l10n.myGroups),
        ),
      ),
    ],
  );

  Widget footer(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Text(
              context.l10n.catalogueNeedsConnection,
              textAlign: TextAlign.center,
            ),
            TextButton.icon(
              onPressed: items.isEmpty ? search : more,
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.retry),
            ),
          ],
        ),
      );
    }
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          query.text.trim().isEmpty
              ? context.l10n.catalogueEmpty
              : context.l10n.noTrailMatch(query.text.trim()),
          textAlign: TextAlign.center,
        ),
      );
    }
    return const SizedBox(height: 24);
  }
}

/// Which colour marks which trails, on the map and in lists.
class TrailColourLegend extends StatelessWidget {
  const TrailColourLegend({super.key});
  @override
  Widget build(BuildContext context) {
    Widget item(bool catalogue, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TrailPinBadge(catalogue: catalogue, size: 20),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        item(false, context.l10n.ownTrailsLegend),
        item(true, context.l10n.catalogueTrailsLegend),
      ],
    );
  }
}

class GroupTile extends StatelessWidget {
  const GroupTile(this.group, {required this.onTap, this.leading, super.key});
  final TrailGroupSummary group;
  final VoidCallback onTap;
  final Widget? leading;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading:
          leading ??
          CircleAvatar(
            backgroundColor: const Color(0xffefe8f6),
            child: Icon(
              group.editorial != null
                  ? Icons.auto_awesome
                  : group.kind == TrailGroupKind.itinerary
                  ? Icons.route
                  : Icons.collections_bookmark_outlined,
              color: catalogueColor,
            ),
          ),
      title: Text(
        groupName(context, group),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        [
          groupSubtitle(context, group),
          if (group.author != null && group.source == walkerSource)
            context.l10n.byAuthor(group.author!),
        ].join(' · '),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}

class CatalogueTrailTile extends StatelessWidget {
  const CatalogueTrailTile(
    this.app,
    this.trail, {
    required this.onTap,
    this.leading,
    this.trailing,
    super.key,
  });
  final AppController app;
  final SharedTrail trail;
  final VoidCallback? onTap;
  final Widget? leading, trailing;
  @override
  Widget build(BuildContext context) {
    final own = app.trails.any(
      (t) => t.id == trail.id || t.publicId == trail.id,
    );
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: leading ?? TrailPinBadge(catalogue: !own),
      title: Text(trail.name),
      subtitle: Wrap(
        spacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(kilometers(trail.metres)),
          if (trail.ref case final ref?)
            Text(ref, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (trail.reviews > 0)
            RatingSummary(count: trail.reviews, average: trail.average),
        ],
      ),
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// Open a group page over the current screen.
Future<void> openGroup(
  BuildContext context,
  AppController app,
  String id, {
  VoidCallback? showMap,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(builder: (_) => GroupPage(app, id, showMap: showMap)),
);

/// A group: its description and source, its members in order (numbered
/// stages for an itinerary), and, for its author, editing.
class GroupPage extends StatefulWidget {
  const GroupPage(this.app, this.id, {this.showMap, super.key});
  final AppController app;
  final String id;
  final VoidCallback? showMap;
  @override
  State<GroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage> {
  TrailGroup? group;
  Object? error;
  bool loading = true;
  AppController get app => widget.app;

  @override
  void initState() {
    super.initState();
    unawaited(load());
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await app.group(widget.id);
      if (mounted) setState(() => group = result);
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> showTrail(SharedTrail trail) async {
    await app.openShared(trail.id);
    if (!mounted || app.focused?.sharedId != trail.id) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    widget.showMap?.call();
  }

  GroupDraft draft(TrailGroup g, {List<TrailGroupMember>? members}) =>
      GroupDraft(
        kind: g.summary.kind,
        name: g.summary.name,
        description: g.description,
        members: [
          for (final m in members ?? g.members)
            GroupMemberRef(
              trailId: m.trail?.id,
              groupId: m.group?.id,
              role: m.role,
            ),
        ],
      );

  Future<void> save(GroupDraft value) async {
    final saved = await app.saveGroup(widget.id, value);
    if (saved != null && mounted) setState(() => group = saved);
  }

  Future<void> edit(TrailGroup g) async {
    final value = await showDialog<GroupDraft>(
      context: context,
      builder: (_) => GroupEditorDialog(initial: draft(g)),
    );
    if (value != null) await save(value);
  }

  Future<void> move(TrailGroup g, int index, int by) async {
    final members = [...g.members];
    final member = members.removeAt(index);
    members.insert(index + by, member);
    await save(draft(g, members: members));
  }

  Future<void> removeMember(TrailGroup g, int index) async {
    final members = [...g.members]..removeAt(index);
    await save(draft(g, members: members));
  }

  Future<void> delete(TrailGroup g) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(context.l10n.deleteGroupQuestion),
        content: Text(context.l10n.deleteGroupInfo),
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
    if (yes == true && await app.removeGroup(widget.id) && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = group;
    return StreamBuilder<void>(
      stream: app.changes.stream,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(g == null ? '' : groupName(context, g.summary)),
          actions: [
            if (g != null && g.summary.mine) ...[
              IconButton(
                tooltip: context.l10n.editGroup,
                onPressed: app.busy ? null : () => edit(g),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: context.l10n.deleteGroup,
                onPressed: app.busy ? null : () => delete(g),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ],
        ),
        body: Column(
          children: [
            if (app.busy)
              LinearProgressIndicator(value: app.progress, minHeight: 3),
            if (app.message != null)
              Material(
                color: const Color(0xffe6ecdf),
                child: ListTile(
                  dense: true,
                  title: Text(context.message(app.message!)),
                  trailing: IconButton(
                    onPressed: () {
                      app.message = null;
                      app.notifyListeners();
                    },
                    icon: const Icon(Icons.close),
                  ),
                ),
              ),
            Expanded(
              child: g == null
                  ? Center(
                      child: loading
                          ? const CircularProgressIndicator()
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(context.message(error)),
                                TextButton.icon(
                                  onPressed: load,
                                  icon: const Icon(Icons.refresh),
                                  label: Text(context.l10n.retry),
                                ),
                              ],
                            ),
                    )
                  : body(context, g),
            ),
          ],
        ),
      ),
    );
  }

  Widget body(BuildContext context, TrailGroup g) {
    final muted = const TextStyle(fontSize: 12, color: mutedInk);
    final description = g.summary.editorial == 'st-james'
        ? context.l10n.stJamesDescription
        : g.details.description(context.l10n.localeName, g.description);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(
          children: [
            if (g.details.marking case final marking?) ...[
              MarkingBadge(marking, size: 36),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                [groupSubtitle(context, g.summary), ?g.summary.ref].join(' · '),
              ),
            ),
          ],
        ),
        if (g.summary.author != null && g.summary.source == walkerSource)
          Text(context.l10n.byAuthor(g.summary.author!), style: muted),
        if (g.parents.isNotEmpty)
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(context.l10n.partOf, style: muted),
              for (final parent in g.parents)
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  label: Text(groupName(context, parent)),
                  onPressed: () => openGroup(
                    context,
                    app,
                    parent.id,
                    showMap: widget.showMap,
                  ),
                ),
            ],
          ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(description),
        ],
        if (g.details.fields['from'] case final from?)
          if (g.details.fields['to'] case final to?)
            Text(context.l10n.fromTo(from, to), style: muted),
        const SizedBox(height: 8),
        if (g.summary.trailCount > 0)
          OutlinedButton.icon(
            onPressed: app.busy || g.summary.trailCount > 150
                ? null
                : () => app.makeGroupAvailableOffline(g),
            icon: const Icon(Icons.download_for_offline_outlined),
            label: Text(
              g.summary.trailCount > 150
                  ? context.l10n.groupTooLargeOffline
                  : context.l10n.makeGroupAvailableOffline,
            ),
          ),
        const Divider(),
        if (g.members.isEmpty) Text(context.l10n.emptyGroup),
        for (var i = 0; i < g.members.length; i++) member(context, g, i),
        if (g.details.openData)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.openStreetMapAttribution,
                    style: muted,
                  ),
                ),
                if (g.details.osmId != null)
                  TextButton(
                    onPressed: () => openDirectionsLink(
                      context,
                      Uri.https(
                        'www.openstreetmap.org',
                        '/${g.details.osmType ?? 'relation'}/${g.details.osmId}',
                      ),
                    ),
                    child: Text(context.l10n.viewOnOpenStreetMap),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget member(BuildContext context, TrailGroup g, int index) {
    final m = g.members[index];
    final editing = g.summary.mine;
    final label = roleLabel(context, m.role, m.stage);
    final badge = CircleAvatar(
      radius: 18,
      backgroundColor: m.role == MemberRole.stage || m.role == MemberRole.main
          ? catalogueColor
          : const Color(0xffefe8f6),
      child: m.role == MemberRole.stage
          ? Text(
              '${m.stage}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            )
          : Icon(
              m.group != null ? Icons.route : Icons.hiking,
              size: 18,
              color: m.role == MemberRole.main ? Colors.white : catalogueColor,
            ),
    );
    final actions = editing
        ? PopupMenuButton<int>(
            tooltip: context.l10n.memberActions,
            onSelected: (action) => switch (action) {
              0 => move(g, index, -1),
              1 => move(g, index, 1),
              _ => removeMember(g, index),
            },
            itemBuilder: (_) => [
              if (index > 0)
                PopupMenuItem(value: 0, child: Text(context.l10n.moveUp)),
              if (index < g.members.length - 1)
                PopupMenuItem(value: 1, child: Text(context.l10n.moveDown)),
              PopupMenuItem(
                value: 2,
                child: Text(context.l10n.removeFromGroup),
              ),
            ],
          )
        : null;
    if (m.group case final nested?) {
      return GroupTile(
        nested,
        leading: badge,
        onTap: () =>
            openGroup(context, app, nested.id, showMap: widget.showMap),
      );
    }
    final trail = m.trail!;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(label, style: const TextStyle(fontSize: 12)),
          ),
          CatalogueTrailTile(
            app,
            trail,
            leading: badge,
            trailing: actions,
            onTap: app.busy ? null : () => showTrail(trail),
          ),
        ],
      ),
    );
  }
}

/// Name, kind and description of a walker's group.
class GroupEditorDialog extends StatefulWidget {
  const GroupEditorDialog({this.initial, super.key});
  final GroupDraft? initial;
  @override
  State<GroupEditorDialog> createState() => _GroupEditorDialogState();
}

class _GroupEditorDialogState extends State<GroupEditorDialog> {
  late final name = TextEditingController(text: widget.initial?.name);
  late final description = TextEditingController(
    text: widget.initial?.description,
  );
  late TrailGroupKind kind = widget.initial?.kind ?? TrailGroupKind.collection;

  @override
  void dispose() {
    name.dispose();
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valid =
        name.text.trim().isNotEmpty &&
        name.text.trim().length <= maximumGroupNameLength;
    return AlertDialog(
      title: Text(
        widget.initial == null ? context.l10n.newGroup : context.l10n.editGroup,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: name,
              autofocus: true,
              maxLength: maximumGroupNameLength,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: context.l10n.groupName),
            ),
            SegmentedButton<TrailGroupKind>(
              segments: [
                ButtonSegment(
                  value: TrailGroupKind.collection,
                  label: Text(context.l10n.collection),
                ),
                ButtonSegment(
                  value: TrailGroupKind.itinerary,
                  label: Text(context.l10n.itinerary),
                ),
              ],
              selected: {kind},
              onSelectionChanged: (v) => setState(() => kind = v.single),
            ),
            const SizedBox(height: 4),
            Text(
              kind == TrailGroupKind.itinerary
                  ? context.l10n.itineraryInfo
                  : context.l10n.collectionInfo,
              style: const TextStyle(fontSize: 12),
            ),
            TextField(
              controller: description,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: context.l10n.groupDescription,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.groupsArePublic,
              style: const TextStyle(fontSize: 12, color: mutedInk),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          onPressed: valid
              ? () => Navigator.pop(
                  context,
                  GroupDraft(
                    kind: kind,
                    name: name.text.trim(),
                    description: description.text.trim(),
                    members: widget.initial?.members ?? const [],
                  ),
                )
              : null,
          child: Text(context.l10n.save),
        ),
      ],
    );
  }
}

/// The walker's groups, to open one or create a new one.
Future<void> showMyGroups(
  BuildContext context,
  AppController app, {
  VoidCallback? showMap,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (sheet) => _GroupPicker(
    app,
    title: sheet.l10n.myGroups,
    onPick: (group) {
      Navigator.pop(sheet);
      openGroup(context, app, group.id, showMap: showMap);
    },
    onCreate: () async {
      final draft = await showDialog<GroupDraft>(
        context: sheet,
        builder: (_) => const GroupEditorDialog(),
      );
      if (draft == null) return;
      final created = await app.createGroup(draft);
      if (created != null && sheet.mounted) {
        Navigator.pop(sheet);
        if (context.mounted) {
          await openGroup(context, app, created.summary.id, showMap: showMap);
        }
      }
    },
  ),
);

/// Add [trail] to one of the walker's groups, or to a new one.
Future<void> addToGroup(BuildContext context, AppController app, Trail trail) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => _GroupPicker(
        app,
        title: sheet.l10n.addToGroup,
        onPick: (group) async {
          Navigator.pop(sheet);
          await app.addToGroup(group, trail);
        },
        onCreate: () async {
          final draft = await showDialog<GroupDraft>(
            context: sheet,
            builder: (_) => const GroupEditorDialog(),
          );
          if (draft == null) return;
          if (sheet.mounted) Navigator.pop(sheet);
          await app.createGroup(
            GroupDraft(
              kind: draft.kind,
              name: draft.name,
              description: draft.description,
              members: [GroupMemberRef(trailId: trail.sharedId)],
            ),
          );
        },
      ),
    );

class _GroupPicker extends StatefulWidget {
  const _GroupPicker(
    this.app, {
    required this.title,
    required this.onPick,
    required this.onCreate,
  });
  final AppController app;
  final String title;
  final void Function(TrailGroupSummary) onPick;
  final Future<void> Function() onCreate;
  @override
  State<_GroupPicker> createState() => _GroupPickerState();
}

class _GroupPickerState extends State<_GroupPicker> {
  late Future<List<TrailGroupSummary>> groups = widget.app.myGroups();
  @override
  Widget build(BuildContext context) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .7,
      ),
      child: FutureBuilder<List<TrailGroupSummary>>(
        future: groups,
        builder: (context, snapshot) => ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: widget.onCreate,
              icon: const Icon(Icons.add),
              label: Text(context.l10n.newGroup),
            ),
            const SizedBox(height: 8),
            if (snapshot.connectionState != ConnectionState.done)
              const Center(child: CircularProgressIndicator())
            else if (snapshot.hasError)
              Column(
                children: [
                  Text(context.l10n.catalogueNeedsConnection),
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => groups = widget.app.myGroups()),
                    icon: const Icon(Icons.refresh),
                    label: Text(context.l10n.retry),
                  ),
                ],
              )
            else if (snapshot.data!.isEmpty)
              Text(context.l10n.noGroupsYet)
            else
              for (final group in snapshot.data!)
                GroupTile(group, onTap: () => widget.onPick(group)),
          ],
        ),
      ),
    ),
  );
}
