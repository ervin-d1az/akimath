import 'dart:ui';

import 'package:ambysmath_app/design/tokens/brand_colors.dart';
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
}
