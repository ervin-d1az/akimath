import 'dart:ui';

import 'package:akimath_app/design/tokens/brand_colors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('coral means error and nothing else', () {
    final Iterable<BrandColorRole> coralRoles = BrandColorRole.values
        .where((BrandColorRole r) => r.color == BrandColors.coral);

    expect(coralRoles, <BrandColorRole>[BrandColorRole.error]);
  });

  test('green means action and success, and only those two', () {
    final Set<BrandColorRole> greenRoles = BrandColorRole.values
        .where((BrandColorRole r) => r.color == BrandColors.green)
        .toSet();

    expect(
      greenRoles,
      <BrandColorRole>{BrandColorRole.action, BrandColorRole.success},
    );
  });

  test('the accent never doubles as a state color', () {
    const Color accent = BrandColors.pink;

    expect(accent, isNot(BrandColorRole.error.color));
    expect(accent, isNot(BrandColorRole.success.color));
    expect(accent, isNot(BrandColorRole.action.color));
  });

  test('success and error are different colors, which is not enough', () {
    // Deuteranopia collapses green and coral toward each other, so color alone
    // cannot carry the distinction. Shape has to. This test only guards the
    // easy half — that the two are at least not literally identical — and
    // exists to keep the harder rule visible next to it.
    expect(BrandColorRole.success.color, isNot(BrandColorRole.error.color));
  });

  test('every role resolves to a fully opaque brand color', () {
    for (final BrandColorRole role in BrandColorRole.values) {
      expect(
        role.color.a,
        1,
        reason: '${role.name} is translucent; opacity is a usage decision.',
      );
    }
  });

  test('the quiet neutral has a name', () {
    expect(BrandColors.quiet, const Color(0xFFEAE6F0));
  });

  test('the figure pink is distinct from the soft pink', () {
    expect(BrandColors.pinkFigure, const Color(0xFFFF9EC1));
    // The requirement is the distinctness, not the hex: the two are 7/6/4
    // apart and the token exists only to keep them apart.
    expect(BrandColors.pinkFigure, isNot(BrandColors.pinkSoft));
  });

  test('the board hairline and the card rule are two tokens, not one alpha',
      () {
    // Asserted numerically on purpose: 0x2E is also the ink's own blue byte,
    // so an eyeballed `0x2E1C1A2E` reads as correct whichever byte moved.
    //
    // **Against `gridHairline`, which is the token both boards draw.** It used
    // to read a byte-identical `hairline` that nothing painted, so this test
    // certified a copy: dropping the board's own alpha to the card rule's `0x29`
    // left all 3358 tests green, measured before the dead token went. The same
    // mutation fails this case by name now.
    expect((BrandColors.gridHairline.a * 255).round(), 46);
    expect((BrandColors.rule.a * 255).round(), 41);
    expect(BrandColors.gridHairline, isNot(BrandColors.rule));

    for (final Color divider in <Color>[
      BrandColors.gridHairline,
      BrandColors.rule,
    ]) {
      expect(divider.r, BrandColors.ink.r);
      expect(divider.g, BrandColors.ink.g);
      expect(divider.b, BrandColors.ink.b);
    }
  });

  test('focus is an accent, not a verdict', () {
    // The three invariant tests above are the other half of this one: focus is
    // permitted precisely because pink still resolves to no verdict role, and
    // none of them was edited to let this through.
    expect(BrandColorRole.focus.color, BrandColors.pink);
  });
}
