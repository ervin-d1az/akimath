import 'package:flutter/widgets.dart';

import '../../../api/me.dart';
import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/brand_button.dart';
import '../../../design/widgets/candy_surface.dart';
import '../../../design/widgets/keypad.dart';
import '../../../design/widgets/spec/keypad_layout.dart';
import '../policy/age_gate.dart';
import '../policy/digit_entry.dart';

/// The gate in front of every door that reaches the server (`req-age-gate`).
///
/// **A neutral date, not a leading question.** "¿Eres mayor de 13?" tells the
/// player which answer opens the door, so it collects a preference rather than
/// a fact. A date does not.
///
/// **The date is reduced here and never kept.** `AgeGate.bandFor` returns a
/// band, this screen hands the band to its caller, and the digits go out of
/// scope with the widget — there is no field for them to be stored in.
///
/// The pad is `KeypadLayout.otp`, the 3×4 the design already declared (D14).
/// The system keyboard never appears for digits in this app.
class AgeGateScreen extends StatefulWidget {
  const AgeGateScreen({
    super.key,
    required this.today,
    required this.onResolved,
  });

  /// Read once at the edge and passed in, so the policy stays clock-free.
  final DateTime today;
  final void Function(AgeBand band, AgeGateRoute route) onResolved;

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
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: BrandShape.space4,
        vertical: BrandShape.space5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // **The copy yields, the pad does not.** At `textScaler` 1.3 the
          // heading and the explanation grow past the viewport; scrolling them
          // keeps the keypad and the button where a thumb expects them, which
          // is the half a player cannot scroll to find.
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text('¿Cuándo naciste?', style: BrandText.sectionTitle()),
                  const SizedBox(height: BrandShape.space2),
                  Text(
                    'Solo guardamos si eres mayor o menor de edad. La fecha no sale de este teléfono.',
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
          const SizedBox(height: BrandShape.space3),
          Keypad(layout: KeypadLayout.otp, onKeyPressed: _onKey),
          const SizedBox(height: BrandShape.space4),
          BrandButton.primary(label: 'Continuar', onPressed: _submit),
        ],
      ),
    );
  }
}
