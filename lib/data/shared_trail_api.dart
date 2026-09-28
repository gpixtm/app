import '../domain/catalogue.dart';
import '../domain/models.dart';
import '../domain/shared_trails.dart';
import 'catalogue_codec.dart';
import 'server_connection.dart';
import 'shared_trail_codec.dart';
import 'trail_codec.dart';

/// Shared trail catalogue, groups, reviews and places of the account's server.
class ApiSharedTrailTransport
    implements SharedTrailTransport, CatalogueTransport {
  ApiSharedTrailTransport(this.server);
  final ServerConnection server;
  static String _path(String id) =>
      '/api/public-trails/${Uri.encodeComponent(id)}';
  static String _group(String id) =>
      '/api/trail-groups/${Uri.encodeComponent(id)}';

  @override
  Future<CatalogueArea> area(Bounds view, {int limit = 300}) async =>
      CatalogueCodec.area(
        await server.request(
          '/api/public-trails/area?south=${view.south}&west=${view.west}'
          '&north=${view.north}&east=${view.east}&limit=$limit',
        ),
      );

  @override
  Future<CataloguePage> search(String query, {String? cursor}) async =>
      CatalogueCodec.page(
        await server.request(
          Uri(
            path: '/api/catalogue/search',
            queryParameters: {'q': query, 'cursor': ?cursor},
          ).toString(),
        ),
      );

  @override
  Future<CatalogueTrail> trail(String id) async {
    final json = await server.request(_path(id));
    final trail = TrailCodec.decode(json);
    return CatalogueTrail(
      trail.withPublicId(trail.id),
      CatalogueCodec.details(json),
    );
  }

  @override
  Future<TrailGroup> group(String id) async =>
      CatalogueCodec.fullGroup(await server.request(_group(id)));

  @override
  Future<List<TrailGroupSummary>> myGroups() async => [
    for (final g
        in (await server.request('/api/my-trail-groups'))['groups'] as List)
      CatalogueCodec.group((g as Map).cast<String, dynamic>()),
  ];

  @override
  Future<TrailGroup> saveGroup(String id, GroupDraft draft) async =>
      CatalogueCodec.fullGroup(
        await server.request(
          _group(id),
          body: CatalogueCodec.encodeDraft(draft),
          method: 'PUT',
        ),
      );

  @override
  Future<void> removeGroup(String id) async {
    await server.request(_group(id), method: 'DELETE');
  }

  @override
  Future<TrailReviews> reviews(String id) async =>
      SharedTrailCodec.decodeReviews(
        await server.request('${_path(id)}/reviews'),
      );

  @override
  Future<TrailReviews> review(String id, int rating, String comment) async =>
      SharedTrailCodec.decodeReviews(
        await server.request(
          '${_path(id)}/review',
          body: {'rating': rating, 'comment': comment},
          method: 'PUT',
        ),
      );

  @override
  Future<TrailPlacePage> places(int since) async =>
      SharedTrailCodec.decodePlaces(
        await server.request('/api/public-places?since=$since'),
      );

  static String _place(TrailPlace p) =>
      '${_path(p.trailId)}/places/${Uri.encodeComponent(p.id)}';

  @override
  Future<TrailPlace> savePlace(TrailPlace place) async =>
      SharedTrailCodec.decodePlace(
        await server.request(
          _place(place),
          body: {
            'lat': place.point.lat,
            'lon': place.point.lon,
            'elevation': place.point.elevation,
            'name': place.name,
            'comment': place.comment,
            'origin': place.origin.name,
          },
          method: 'PUT',
        ),
      );

  @override
  Future<TrailPlace> removePlace(TrailPlace place) async =>
      SharedTrailCodec.decodePlace(
        await server.request(_place(place), method: 'DELETE'),
      );

  @override
  Future<TrailReviews> removeReview(String id) async =>
      SharedTrailCodec.decodeReviews(
        await server.request('${_path(id)}/review', method: 'DELETE'),
      );
}
