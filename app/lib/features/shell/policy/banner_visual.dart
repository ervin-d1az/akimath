import '../../../design/icons/spec/brand_glyph.dart';

/// What a banner is telling the player.
///
/// **The hue encodes whose fault it is**, which is why there is no `offline`
/// variant: *"Sin conexión no es un error del usuario: va en amarillo."* A lost
/// connection is a `notice`. Something the player must fix is an `error`.
enum BannerKind {
  /// Coral. Something is wrong that the player can act on.
  error,

  /// Yellow. Something is true that is nobody's fault.
  notice,
}

/// Where a banner sits. K7: the two skins are a placement, not two widgets.
enum BannerPlacement { inline, topBand }

/// The colour a banner carries, as a role rather than a hue.
///
/// A role and never a `Color`, on the same construction as `Verdict` and
/// `MasteryLevel`: the adapter resolves it, so no call site can decide what a
/// banner means by picking a colour.
enum BannerTone { error, notice }

/// How a banner is drawn, and it always has a glyph.
///
/// **The glyph is not optional, and that is the whole reason this type exists.**
/// A banner distinguished only by hue is unreadable to someone who cannot
/// separate coral from yellow — BRD-1's problem, in a different widget.
///
/// It does not reuse `Verdict`, and the deviation is deliberate. `Verdict` is
/// right-or-wrong and carries exactly two glyphs; the no-connection banner needs
/// **wifi-off**, which is neither. Widening `Verdict` to fit a banner would make
/// a verdict type that no longer means a verdict. Same construction, separate
/// type.
class BannerVisual {
  const BannerVisual({
    required this.glyph,
    required this.tone,
  });

  final BrandGlyph glyph;
  final BannerTone tone;
}

/// The visual for a banner of [kind].
///
/// Pure: an enum in, a value out.
BannerVisual resolveBannerVisual(BannerKind kind) => switch (kind) {
      BannerKind.error =>
        const BannerVisual(glyph: BrandGlyph.alert, tone: BannerTone.error),
      BannerKind.notice =>
        const BannerVisual(glyph: BrandGlyph.wifiOff, tone: BannerTone.notice),
    };
