/// Distances measured on the imported trace, in metres; descending means reverse.
class WalkingDay {
  const WalkingDay(this.start, this.end);
  final double start, end;
  double get length => (end - start).abs();
  bool valid(double total) =>
      start.isFinite &&
      end.isFinite &&
      start >= 0 &&
      end >= 0 &&
      start <= total &&
      end <= total &&
      length >= 10;
}
