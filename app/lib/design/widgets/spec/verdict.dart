import '../../icons/spec/brand_glyph.dart';

/// How a verdict's outline is drawn.
enum VerdictOutline { solid, dashed }

/// Right or wrong, carrying **no colour**.
///
/// BRD-1: success and error must be distinguishable by *shape*, not hue alone,
/// because deuteranopia collapses green and coral. The corpus distinguishes them
/// by hue on every screen but one — two 22 px circles with an identical 3 px
/// border, `#5ED6A4` against `#FF8A5B`.
///
/// The type could carry a colour and document that shape must also be used.
/// That documents a rule. **Carrying no colour makes hue-only unrepresentable**:
/// a call site has to reach for the outline or the glyph, because that is all
/// there is. Same construction as the sync endpoint refusing an `ok` field.
///
/// **Two channels, unequal in status.** The glyph is mandatory everywhere — it
/// is the one nothing else has spent. The outline is honoured where it is free:
/// `ItemTermTile`'s `unknown` state is already dashed on five of the six
/// stimulus screens, so on that widget `wrong` cannot claim the dash without
/// colliding with "still to fill". Which channel `unknown` gives up is DR-4, a
/// design decision rather than a code one.
///
/// The encoding is **always on** (D6). `4.5`'s *Modo daltonismo* toggle only
/// adds redundancy — an invariant behind a setting is not an invariant.
enum Verdict {
  correct(outline: VerdictOutline.solid, glyph: BrandGlyph.check),
  wrong(outline: VerdictOutline.dashed, glyph: BrandGlyph.alert);

  const Verdict({required this.outline, required this.glyph});

  final VerdictOutline outline;
  final BrandGlyph glyph;
}
