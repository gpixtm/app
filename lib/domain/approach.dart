import 'models.dart';
import 'trail_geometry.dart';

class DirectionStep {
  const DirectionStep(this.along, this.instruction);
  final double along;
  final String instruction;
}

class ApproachRoute {
  ApproachRoute(this.trail, this.steps, this.seconds, {this.cached = false});
  final Trail trail;
  final List<DirectionStep> steps;
  final double seconds;
  final bool cached;
  DirectionStep? next(double along) =>
      steps.where((s) => s.along >= along - 8).firstOrNull ?? steps.lastOrNull;

  bool arrived(TrackingSession session, GeoPoint destination, DateTime now) {
    final fix = session.fix;
    return fix != null &&
        fix.reliable(now) &&
        fix.accuracy <= 25 &&
        distance(fix.point, destination) <= 25 &&
        session.geometry.total - (session.projection?.along ?? 0) < 50;
  }
}

GeoPoint? nearestConnection(Trail trail, GeoPoint origin) =>
    TrailGeometry(trail).project(origin)?.point;

abstract interface class ApproachSource {
  Future<ApproachRoute> calculate(
    GeoPoint origin,
    Trail target,
    GeoPoint destination,
  );
}
