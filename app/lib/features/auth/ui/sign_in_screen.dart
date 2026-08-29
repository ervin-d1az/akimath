import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/brand_button.dart';
import '../../../design/widgets/detail_header.dart';
import '../../shell/policy/banner_visual.dart';
import '../../shell/ui/inline_banner.dart';
import '../policy/credential_rules.dart';
import 'labelled_field.dart';

/// `Iniciar sesión`.
///
/// **The account already exists, so nothing here creates one.** A session comes
/// straight back and the only step left is the token — there is no code to ask
/// for, because signing in is only possible once the address is verified.
///
/// **No Google or Apple button and no `O` divider.** The design draws all
/// three; D13 cut them, and the provider's Google is on Neon's shared consent
/// screen besides — the same reasoning `1.2` records.
///
/// **The refusal is drawn as `1.7` draws it**: a coral band with the alert
/// glyph, not a hue on its own. Deuteranopia collapses coral and green, so the
/// glyph is what carries the meaning (BRD-1), and `InlineBanner` is where that
/// pairing already lives.
class SignInScreen extends StatefulWidget {
  const SignInScreen({
    super.key,
    required this.onSubmit,
    required this.busy,
    required this.onBack,
    required this.onForgotPassword,
    this.initialEmail = '',
    this.problem,
  });

  final void Function(String email, String password) onSubmit;
  final bool busy;

  /// Back to `1.2`, which is where this screen is reached from.
  final VoidCallback onBack;

  /// `1.4`. Carries whatever address is typed, so a player does not write it
  /// twice.
  final void Function(String email) onForgotPassword;

  final String initialEmail;
  final String? problem;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  late final TextEditingController _email = TextEditingController(
    text: widget.initialEmail,
  );
  final TextEditingController _password = TextEditingController();
  String? _local;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// **The address is checked and the password is not.** A malformed address
  /// cannot match any account, so refusing it here saves a round trip that
  /// could only fail. A password is the provider's to judge: applying
  /// `longEnough` would lock out an account whose password predates that floor
  /// without ever asking, and the answer to a wrong one is the same either way.
  void _submit() {
    final String email = _email.text.trim();
    final String password = _password.text;
    setState(() {
      if (!CredentialRules.looksLikeEmail(email)) {
        _local = 'Revisa el correo.';
      } else if (password.isEmpty) {
        _local = 'Escribe tu contraseña.';
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
        DetailHeader(title: 'INICIA SESIÓN', onBack: widget.onBack),
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
                LabelledField(
                  label: 'CORREO',
                  controller: _email,
                  fieldKey: const Key('sign-in-email'),
                  enabled: !widget.busy,
                ),
                const SizedBox(height: BrandShape.space3),
                LabelledField(
                  label: 'CONTRASEÑA',
                  controller: _password,
                  fieldKey: const Key('sign-in-password'),
                  obscure: true,
                  enabled: !widget.busy,
                ),
                if (message != null) ...<Widget>[
                  const SizedBox(height: BrandShape.space3),
                  InlineBanner(
                    key: const Key('sign-in-problem'),
                    kind: BannerKind.error,
                    message: message,
                  ),
                ],
                const SizedBox(height: BrandShape.space3),
                Align(
                  alignment: Alignment.centerLeft,
                  child: BrandButton.text(
                    label: '¿Olvidaste tu contraseña?',
                    onPressed: () =>
                        widget.onForgotPassword(_email.text.trim()),
                  ),
                ),
                const SizedBox(height: BrandShape.space3),
                BrandButton.primary(
                  label: widget.busy ? 'Entrando…' : 'Entrar',
                  onPressed: widget.busy ? () {} : _submit,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
