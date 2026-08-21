import 'package:flutter/material.dart'
    show InputBorder, InputDecoration, TextField;
import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/candy_surface.dart';

/// An eyebrow above a boxed text field, which is every field the account
/// screens draw.
///
/// **One widget because four screens draw the same thing.** `1.1`, `1.2`, `1.4`
/// and `1.5` each ask for an address or a password inside the same white
/// `CandySurface`; a private copy per screen is four places that would drift on
/// the padding, the border or the label's case.
///
/// **The system keyboard is right here and only here.** The ban is on digits —
/// a date and a six-digit code are typed on `KeypadLayout.otp` (D14) — and an
/// address or a password is neither.
class LabelledField extends StatelessWidget {
  const LabelledField({
    super.key,
    required this.label,
    required this.controller,
    required this.fieldKey,
    this.obscure = false,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;

  /// Goes on the `TextField` itself, so a test drives the input rather than the
  /// box drawn around it.
  final Key fieldKey;

  final bool obscure;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: BrandText.eyebrow()),
        const SizedBox(height: BrandShape.space1),
        CandySurface(
          padding: const EdgeInsets.symmetric(
            horizontal: BrandShape.space3,
            vertical: BrandShape.space2,
          ),
          child: TextField(
            key: fieldKey,
            controller: controller,
            obscureText: obscure,
            enabled: enabled,
            style: BrandText.body(),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }
}
