import '../domain/models.dart';
import '../domain/shared_trails.dart';
import 'server_connection.dart';
import 'shared_trail_codec.dart';
import 'trail_codec.dart';

/// Shared trail catalogue and reviews of the account's server.
class ApiSharedTrailTransport implements SharedTrailTransport {
  ApiSharedTrailTransport(this.server);
  final ServerConnection server;
  static String _path(String id) =>
      '/api/public-trails/${Uri.encodeComponent(id)}';

  @override
  Future<SharedTrailPage> index(int since) async => SharedTrailCodec.decodePage(
    await server.request('/api/public-trails?since=$since'),
  );

  @override
  Future<Trail> download(String id) async {
    final trail = TrailCodec.decode(await server.request(_path(id)));
    return trail.withPublicId(trail.id);
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
