import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/brand_button.dart';
import '../../../design/widgets/detail_header.dart';
import '../policy/credential_rules.dart';
import 'labelled_field.dart';

/// `Crear cuenta`.
///
/// **No `CÓMO TE LLAMO` field** — Q5, decided: a player has no name, `players`
/// has no column for one, and `4.1` greets the address. The account is an
/// email, a password, and nothing else.
///
/// **No Google or Apple button and no `O` divider** — D13 cut them from `1.1`,
/// and the provider's Google is on Neon's shared consent screen besides.
///
/// **Unreachable without a band.** `AuthFlow` puts `AgeGateScreen` in front and
/// routes anything under the threshold to consent instead; this screen takes the
/// band as a required argument so it cannot be built without one.
class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({
    super.key,
    required this.onSubmit,
    required this.busy,
    required this.onBack,
    required this.onSignInInstead,
    this.problem,
  });

  final void Function(String email, String password) onSubmit;
  final bool busy;

  /// Back to the gate. Re-answering the date is harmless: a band under the
  /// threshold lands on consent, which is the routing this screen sits behind.
  final VoidCallback onBack;

  /// `1.1`. The design's footer — *"¿No tienes cuenta? Créala"* — read from the
  /// other side, because this flow's one entrance is the profile's
  /// `Crear cuenta` row: a player who already has an account arrives here, and
  /// without this door the only way on is to create a second one.
  final VoidCallback onSignInInstead;

  final String? problem;

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  String? _local;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final String email = _email.text.trim();
    final String password = _password.text;
    // Checked here so the message lands under the field rather than after a
    // round trip that says 400 — `CredentialRules` is pure and shared.
    setState(() {
      if (!CredentialRules.looksLikeEmail(email)) {
        _local = 'Revisa el correo.';
      } else if (!CredentialRules.longEnough(password)) {
        _local =
            'La contraseña necesita al menos '
            '${CredentialRules.minimumPasswordLength} caracteres.';
      } else {
        _local = null;
      }
    });
    if (_local == null) {
      widget.onSubmit(email, password);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? message = _local ?? widget.problem;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DetailHeader(title: 'CREAR CUENTA', onBack: widget.onBack),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              BrandShape.space4,
              BrandShape.space3,
              BrandShape.space4,
              BrandShape.space5,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Con una cuenta tus retos te siguen a otro teléfono.',
                  style: BrandText.body(),
                ),
                const SizedBox(height: BrandShape.space4),
                LabelledField(
                  label: 'CORREO',
                  controller: _email,
                  fieldKey: const Key('create-account-email'),
                  enabled: !widget.busy,
                ),
                const SizedBox(height: BrandShape.space3),
                LabelledField(
                  label: 'CONTRASEÑA',
                  controller: _password,
                  fieldKey: const Key('create-account-password'),
                  obscure: true,
                  enabled: !widget.busy,
                ),
                if (message != null) ...<Widget>[
                  const SizedBox(height: BrandShape.space3),
                  Text(
                    message,
                    key: const Key('create-account-problem'),
                    style: BrandText.caption().copyWith(
                      color: BrandColors.coral,
                    ),
                  ),
                ],
                const SizedBox(height: BrandShape.space5),
                BrandButton.primary(
                  label: widget.busy ? 'Creando…' : 'Crear cuenta',
                  onPressed: widget.busy ? () {} : _submit,
                ),
                const SizedBox(height: BrandShape.space2),
                BrandButton.text(
                  label: 'Ya tengo cuenta',
                  onPressed: widget.onSignInInstead,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
