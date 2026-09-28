import 'models.dart';
import 'shared_trails.dart';

/// The server's catalogue of every trail, browsed without copying it to the
/// phone: trails in the visible map area, a paginated search, trail and group
/// pages, and the groups walkers make. Only a trail the walker makes available
/// offline, or starts walking, is stored on the phone.
enum TrailGroupKind { itinerary, collection }

/// A member's part in its group: its main line, one of its numbered stages,
/// or a variant, link, excursion or approach beside them.
enum MemberRole { main, stage, variant, link, excursion, approach }

/// Source of walkers' own trails and groups; others come from open data.
const walkerSource = 'gpix';

class TrailGroupSummary {
  const TrailGroupSummary({
    required this.id,
    required this.kind,
    required this.name,
    required this.metres,
    required this.trailCount,
    required this.source,
    this.editorial,
    this.ref,
    this.bounds,
    this.author,
    this.mine = false,
  });
  final String id, name, source;
  final TrailGroupKind kind;

  /// Key of a collection Gpix curates, whose name the app translates.
  final String? editorial;
  final String? ref, author;
  final double metres;
  final int trailCount;
  final Bounds? bounds;

  /// The walker made this group and may change it.
  final bool mine;
}

/// Where a trail belongs: its groups from the outermost to the one holding it.
class TrailGroupPath {
  const TrailGroupPath(this.groups, this.role, {this.stage});
  final List<TrailGroupSummary> groups;
  final MemberRole role;
  final int? stage;
}

/// What the source says about a trail or group, beyond its line: reference,
/// waymarks, descriptions in their original languages, links and licence.
/// Source text is shown as it is, never translated.
class TrailDetails {
  const TrailDetails({
    required this.source,
    this.licence,
    this.attribution,
    this.fields = const {},
    this.descriptions = const {},
    this.roundtrip,
    this.pilgrimage = false,
    this.osmType,
    this.osmId,
    this.author,
    this.metres,
    this.reviews = 0,
    this.average,
    this.paths = const [],
    this.hidden = false,
  });
  final String source;
  final String? licence, attribution, author;

  /// `ref`, `network`, `marking` (OSM `osmc:symbol`), `from`, `to`, `via`,
  /// `operator`, `website`, `wikidata`, `wikipedia`, `distance`, `ascent`…
  final Map<String, String> fields;

  /// Descriptions by language code; `default` has no stated language.
  final Map<String, String> descriptions;
  final bool? roundtrip;
  final bool pilgrimage;
  final String? osmType;
  final int? osmId;
  final double? metres;
  final int reviews;
  final double? average;
  final List<TrailGroupPath> paths;

  /// Withdrawn from its source; kept for the walks and copies using it.
  final bool hidden;

  bool get openData => source != walkerSource;
  String? get ref => fields['ref'];
  String? get marking => fields['marking'];

  /// The description in [language] when the source has one, else the untagged
  /// one, else the first given, else [fallback].
  String description(String language, String fallback) =>
      descriptions[language] ??
      descriptions['default'] ??
      descriptions.values.firstOrNull ??
      fallback;

  static const walker = TrailDetails(source: walkerSource);
}

/// A full trail with its details, as the trail page shows it.
class CatalogueTrail {
  const CatalogueTrail(this.trail, this.details);
  final Trail trail;
  final TrailDetails details;
}

sealed class CatalogueItem {
  const CatalogueItem();
}

class CatalogueTrailItem extends CatalogueItem {
  const CatalogueTrailItem(this.trail);
  final SharedTrail trail;
}

class CatalogueGroupItem extends CatalogueItem {
  const CatalogueGroupItem(this.group);
  final TrailGroupSummary group;
}

/// One page of search results; [next] is an opaque cursor, null at the end.
class CataloguePage {
  const CataloguePage(this.items, this.next);
  final List<CatalogueItem> items;
  final String? next;
}

/// Trails in a map area, longest first; [truncated] when more exist there.
class CatalogueArea {
  const CatalogueArea(this.trails, this.truncated);
  final List<SharedTrail> trails;
  final bool truncated;
}

class TrailGroupMember {
  const TrailGroupMember(this.role, {this.stage, this.trail, this.group});
  final MemberRole role;
  final int? stage;
  final SharedTrail? trail;
  final TrailGroupSummary? group;
}

class TrailGroup {
  const TrailGroup({
    required this.summary,
    required this.members,
    this.description = '',
    this.details = TrailDetails.walker,
    this.parents = const [],
  });
  final TrailGroupSummary summary;
  final String description;
  final TrailDetails details;
  final List<TrailGroupMember> members;
  final List<TrailGroupSummary> parents;

  /// The trails directly in this group, in order.
  List<SharedTrail> get trails => [for (final m in members) ?m.trail];
}

/// A member of a group the walker makes: a trail or another group.
class GroupMemberRef {
  const GroupMemberRef({this.trailId, this.groupId, this.role});
  final String? trailId, groupId;
  final MemberRole? role;
}

class GroupDraft {
  const GroupDraft({
    required this.kind,
    required this.name,
    this.description = '',
    this.members = const [],
  });
  final TrailGroupKind kind;
  final String name, description;
  final List<GroupMemberRef> members;
}

const maximumGroupNameLength = 200;
const maximumGroupMembers = 500;

abstract interface class CatalogueTransport {
  Future<CatalogueArea> area(Bounds view, {int limit});
  Future<CataloguePage> search(String query, {String? cursor});
  Future<CatalogueTrail> trail(String id);
  Future<TrailGroup> group(String id);
  Future<List<TrailGroupSummary>> myGroups();

  /// Create or replace the walker's group; the phone chooses [id].
  Future<TrailGroup> saveGroup(String id, GroupDraft draft);
  Future<void> removeGroup(String id);
}
