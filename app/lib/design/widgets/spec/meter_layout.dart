/// The geometry of a progress meter, as pure data.
///
/// A track, a fill, and an optional 6 px ink marker showing where the player
/// started — the "baseline" the meter is named for.
library;

/// The track heights the documents draw.
enum MeterTrack {
  hairline(9),
  slim(10),
  compact(12),

  /// `04 Error`'s inline meter.
  inline(14),

  /// `03 Acierto`'s meter.
  standard(16);

  const MeterTrack(this.height);

  final double height;
}

class MeterLayout {
  const MeterLayout._(this.trackHeight);

  /// The ink marker's width. One number for every track.
  static const double markerWidth = 6;

  factory MeterLayout.of(MeterTrack track) => MeterLayout._(track.height);

  final double trackHeight;

  /// How far the marker stands proud of the track at each end.
  ///
  /// **A function of track height, not a second decision** — h14 gives ±4 and
  /// h16 gives ±5, and the plan says "no exceptions". Deriving it means a track
  /// added later cannot bring an overhang of its own, which is exactly the kind
  /// of per-instance number that turns one component into five.
  double get overhang => (trackHeight - markerWidth) / 2;

  /// The marker's full height: the track plus its overhang at both ends.
  double get markerHeight => trackHeight + 2 * overhang;

  /// How wide the fill is across a track of [trackWidth].
  ///
  /// [fraction] is clamped rather than trusted. A value outside 0..1 would
  /// otherwise paint a fill wider than its track — and a painter's overflow is
  /// invisible to `screen_overflow_test`, which walks the widget tree.
  double fillWidth(double trackWidth, double fraction) =>
      trackWidth * fraction.clamp(0.0, 1.0);
}
