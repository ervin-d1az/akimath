import 'package:flutter/widgets.dart';

import '../../../api/me.dart';
import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/brand_button.dart';
import '../../../design/widgets/candy_surface.dart';
import '../../../design/widgets/detail_header.dart';
import '../../../design/widgets/keypad.dart';
import '../../../design/widgets/spec/keypad_layout.dart';
import '../policy/age_gate.dart';
import '../policy/digit_entry.dart';

/// The gate in front of every door that reaches the server
/// (`req-no-account-without-a-declaration`).
///
/// **A neutral date, not a leading question.** "¿Eres mayor de edad?" tells the
/// player which answer opens the door, so it collects a preference rather than
/// a fact. A date does not. That matters more after ADR 0004 than it did
/// before: the answer below the threshold is now a refusal rather than a
/// consolation, so the incentive to type a different year is larger and the
/// question must not say which year that is.
///
/// **The date is reduced here and never kept.** `AgeGate.bandFor` returns a
/// band, this screen hands the band to its caller, and the digits go out of
/// scope with the widget — there is no field for them to be stored in.
///
/// The pad is `KeypadLayout.otp`, the 3×4 the design already declared (D14).
/// The system keyboard never appears for digits in this app.
///
/// **A refusal has to stay true for as long as it stays up.** The flow lives
/// inside a tab an `IndexedStack` keeps alive, so a message survives a trip to
/// another tab and back — measured, not assumed. Over an untouched
/// `DD/MM/AAAA` the single refusal this screen used to have read
/// *"Revisa la fecha."*, which accused the player of a date they had never
/// typed. An empty field is asked rather than corrected, and that message is
/// true however long it is left on screen.
class AgeGateScreen extends StatefulWidget {
  const AgeGateScreen({
    super.key,
    required this.today,
    required this.onResolved,
    required this.onBack,
  });

  /// Read once at the edge and passed in, so the policy stays clock-free.
  final DateTime today;
  final void Function(AgeBand band, AgeGateOutcome outcome) onResolved;

  /// Leaves the flow. The gate is its first step, so there is nothing behind it.
  final VoidCallback onBack;

  @override
  State<AgeGateScreen> createState() => _AgeGateScreenState();
}

class _AgeGateScreenState extends State<AgeGateScreen> {
  String _typed = '';
  String? _problem;

  DateTime? get _date => DigitEntry.dateFrom(_typed);

  void _onKey(KeypadKey key) {
    setState(() {
      _problem = null;
      if (key.id == 'backspace') {
        _typed = DigitEntry.pop(_typed);
      } else if (key.id == 'enter') {
        _resolveNow();
      } else if (key.emits != null) {
        _typed = DigitEntry.push(_typed, key.emits!, max: 8);
      }
    });
  }

  /// Both the pad's enter key and the button come through here, so a refusal
  /// repaints either way. The first version wired the button straight to
  /// `_resolveNow`, outside `setState`, and the message never appeared.
  void _submit() => setState(_resolveNow);

  void _resolveNow() {
    if (_typed.isEmpty) {
      _problem = 'Escribe tu fecha de nacimiento.';
      return;
    }
    final DateTime? date = _date;
    if (date == null) {
      _problem = 'Revisa la fecha.';
      return;
    }
    if (date.isAfter(widget.today)) {
      _problem = 'Esa fecha aún no llega.';
      return;
    }
    final AgeBand band = AgeGate.bandFor(bornOn: date, today: widget.today);
    widget.onResolved(band, AgeGate.next(band));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DetailHeader(title: '¿CUÁNDO NACISTE?', onBack: widget.onBack),
        // **The copy yields, the pad does not.** At `textScaler` 1.3 the
        // explanation grows past the viewport; scrolling it keeps the keypad
        // and the button where a thumb expects them, which is the half a
        // player cannot scroll to find.
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
                  'Solo guardamos si eres mayor o menor de edad. La fecha no '
                  'sale de este teléfono.',
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
                    DigitEntry.maskedDate(_typed),
                    key: const Key('age-gate-date'),
                    style: BrandText.numeral(28),
                  ),
                ),
                if (_problem != null) ...<Widget>[
                  const SizedBox(height: BrandShape.space2),
                  Text(
                    _problem!,
                    key: const Key('age-gate-problem'),
                    style: BrandText.caption().copyWith(
                      color: BrandColors.coral,
                    ),
                  ),
                ],
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
              const SizedBox(height: BrandShape.space4),
              BrandButton.primary(label: 'Continuar', onPressed: _submit),
            ],
          ),
        ),
      ],
    );
  }
}
