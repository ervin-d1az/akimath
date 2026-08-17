import 'package:akimath_app/design/widgets/spec/meter_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the marker overhang is a function of track height', () {
    // Asserted through the **named track constants** the app uses, not through
    // numbers this test builds — the `f0-dashed-border` lesson, where a
    // falsification passed because the test constructed its own pattern and
    // left the shipped constants pinned by nothing.
    test('the two measured rows', () {
      expect(MeterLayout.of(MeterTrack.inline).overhang, 4);
      expect(MeterLayout.of(MeterTrack.standard).overhang, 5);
    });

    test('inline is h14 and standard is h16', () {
      expect(MeterTrack.inline.height, 14);
      expect(MeterTrack.standard.height, 16);
    });

    test('every track derives its overhang from the same rule', () {
      // "The marker overhang is a function of track height, not a second
      // decision — no exceptions." So a track added later cannot bring its own.
      for (final MeterTrack track in MeterTrack.values) {
        expect(
          MeterLayout.of(track).overhang,
          (track.height - MeterLayout.markerWidth) / 2,
          reason: '${track.name} carries an overhang of its own',
        );
      }
    });

    test('the marker is 6px of ink and overhangs both ends', () {
      final MeterLayout inline = MeterLayout.of(MeterTrack.inline);

      expect(MeterLayout.markerWidth, 6);
      expect(inline.markerHeight, inline.trackHeight + 2 * inline.overhang);
      expect(inline.markerHeight, 22);
      expect(MeterLayout.of(MeterTrack.standard).markerHeight, 26);
    });

    test('the five drawn sizes all exist', () {
      // h9 / h10 / h12 / h14 / h16, per the component inventory.
      expect(
        MeterTrack.values.map((MeterTrack t) => t.height).toList(),
        <double>[9, 10, 12, 14, 16],
      );
    });
  });

  group('the fill fraction is clamped, not trusted', () {
    test('a fraction outside 0..1 is clamped rather than overflowing', () {
      // A rating that outran its own maximum would otherwise paint a fill wider
      // than its track, which the overflow gate cannot see inside a painter.
      expect(MeterLayout.of(MeterTrack.inline).fillWidth(100, -0.5), 0);
      expect(MeterLayout.of(MeterTrack.inline).fillWidth(100, 1.5), 100);
      expect(MeterLayout.of(MeterTrack.inline).fillWidth(100, 0.25), 25);
    });
  });
}
