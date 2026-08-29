import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/brand_button.dart';
import '../../../design/widgets/candy_surface.dart';
import '../../../design/widgets/detail_header.dart';
import '../../../design/widgets/keypad.dart';
import '../../../design/widgets/spec/keypad_layout.dart';
import '../policy/credential_rules.dart';
import '../policy/digit_entry.dart';

/// `Verificar correo`.
///
/// **The code is typed on the 3×4 pad** (D14), never on the system keyboard.
///
/// **The code has to be asked for.** `sendVerificationEmailOnSignUp` is off in
/// the provider, so creating the account sends nothing — `AuthFlow` requests one
/// on the way in, and this screen can request another once the cooldown is up.
///
/// The cooldown is `CredentialRules`, which is pure and takes both timestamps;
/// this screen owns the ticker that supplies `now`.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({
    super.key,
    required this.email,
    required this.codeIssuedAt,
    required this.onSubmit,
    required this.onResend,
    required this.busy,
    required this.onBack,
    this.problem,
  });

  final String email;
  final DateTime codeIssuedAt;
  final void Function(String code) onSubmit;
  final VoidCallback onResend;
  final bool busy;

  /// Back to `1.2`. The account already exists by the time this screen is
  /// drawn, so re-submitting the same address is refused by the provider —
  /// which is the correct answer, and the address is the thing a player comes
  /// back here to change.
  final VoidCallback onBack;

  final String? problem;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  static const int _codeLength = 6;

  String _typed = '';
  DateTime _now = DateTime.now();
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // One second, because that is the resolution `0:42` shows. A `Ticker` would
    // redraw the same string sixty times a second.
    _tick = Timer.periodic(
      const Duration(seconds: 1),
      (Timer _) => setState(() => _now = DateTime.now()),
    );
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _onKey(KeypadKey key) {
    setState(() {
      if (key.id == 'backspace') {
        _typed = DigitEntry.pop(_typed);
      } else if (key.id == 'enter') {
        _submit();
      } else if (key.emits != null) {
        _typed = DigitEntry.push(_typed, key.emits!, max: _codeLength);
      }
    });
  }

  void _submit() {
    if (CredentialRules.looksLikeCode(_typed, digits: _codeLength) &&
        !widget.busy) {
      widget.onSubmit(_typed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Duration left = CredentialRules.remainingCooldown(
      widget.codeIssuedAt,
      _now,
    );
    final bool canResend = left == Duration.zero && !widget.busy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DetailHeader(title: 'REVISA TU CORREO', onBack: widget.onBack),
        // See `age_gate_screen.dart`: the copy scrolls at large text scales so
        // the pad and the resend button stay where a thumb expects them.
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              BrandShape.space4,
              BrandShape.space3,
              BrandShape.space4,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Te enviamos un código de $_codeLength dígitos a ${widget.email}.',
                  style: BrandText.body(),
                ),
                const SizedBox(height: BrandShape.space4),
                CandySurface(
                  padding: const EdgeInsets.symmetric(
                    horizontal: BrandShape.space4,
                    vertical: BrandShape.space3,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _typed.padRight(_codeLength, '·').split('').join(' '),
                    key: const Key('verify-code'),
                    style: BrandText.numeral(28),
                  ),
                ),
                if (widget.problem != null) ...<Widget>[
                  const SizedBox(height: BrandShape.space2),
                  Text(
                    widget.problem!,
                    key: const Key('verify-problem'),
                    style: BrandText.caption().copyWith(
                      color: BrandColors.coral,
                    ),
                  ),
                ],
                const SizedBox(height: BrandShape.space3),
                Text(
                  canResend
                      ? 'No llegó nada.'
                      : 'Puedes pedir otro en ${CredentialRules.formatCooldown(left)}.',
                  key: const Key('verify-cooldown'),
                  style: BrandText.caption(),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            BrandShape.space4,
            BrandShape.space3,
            BrandShape.space4,
            BrandShape.space5,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Keypad(layout: KeypadLayout.otp, onKeyPressed: _onKey),
              const SizedBox(height: BrandShape.space3),
              BrandButton.secondary(
                label: 'Enviar otro código',
                onPressed: canResend ? widget.onResend : () {},
              ),
            ],
          ),
        ),
      ],
    );
  }
}
