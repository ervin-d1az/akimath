import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';
import 'spec/mastery_level.dart';
import 'spec/meter_layout.dart';

/// A progress track with an optional ink marker showing where the player began.
///
/// **It takes a [MasteryLevel] and has no `Color` parameter at all.** That is
/// the whole requirement: with no colour to pass, a call site cannot decide
/// what a fill means by picking a hue, and the mapping from level to colour
/// lives here — one place — rather than in every screen that draws a bar.
///
/// The geometry is `MeterLayout`'s: the marker's overhang is derived from the
/// track height, so a new track size cannot bring an overhang of its own.
class BaselineMeter extends StatelessWidget {
  const BaselineMeter({
    super.key,
    required this.fill,
    required this.fraction,
    this.track = MeterTrack.standard,
    this.baseline,
  });

  /// What the fill means. Never a colour.
  final MasteryLevel fill;

  /// How full the track is, 0..1. Clamped by [MeterLayout.fillWidth].
  final double fraction;

  final MeterTrack track;

  /// Where the player started, 0..1. Null draws no marker.
  final double? baseline;

  /// The one place a level becomes a hue.
  ///
  /// All four arms are exercised by `baseline_meter_test.dart`, so none is
  /// unreachable behind an enum a test merely pins — the failure mode a review
  /// found in `MathTone.muted` and this type is shaped to avoid.
  Color get _fillColor => switch (fill) {
        MasteryLevel.locked => BrandColorRole.secondaryText.color,
        MasteryLevel.available => BrandColorRole.accent.color,
        MasteryLevel.inProgress => BrandColorRole.highlight.color,
        MasteryLevel.mastered => BrandColorRole.success.color,
      };

  @override
  Widget build(BuildContext context) {
    final MeterLayout layout = MeterLayout.of(track);
    final double? marker = baseline;

    return SizedBox(
      height: layout.markerHeight,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double width = constraints.maxWidth;
          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              // The track.
              Container(
                height: layout.trackHeight,
                decoration: BoxDecoration(
                  color: BrandColors.quiet,
                  borderRadius:
                      BorderRadius.circular(layout.trackHeight / 2),
                ),
              ),
              // The fill.
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  height: layout.trackHeight,
                  width: layout.fillWidth(width, fraction),
                  decoration: BoxDecoration(
                    color: _fillColor,
                    borderRadius:
                        BorderRadius.circular(layout.trackHeight / 2),
                  ),
                ),
              ),
              if (marker != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: (layout.fillWidth(width, marker) -
                              MeterLayout.markerWidth / 2)
                          .clamp(0.0, width - MeterLayout.markerWidth),
                    ),
                    child: SizedBox(
                      width: MeterLayout.markerWidth,
                      height: layout.markerHeight,
                      child: const ColoredBox(color: BrandColors.ink),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
