import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/brand_button.dart';
import '../../../design/widgets/detail_header.dart';
import '../../shell/policy/banner_visual.dart';
import '../../shell/ui/inline_banner.dart';
import '../policy/credential_rules.dart';
import 'labelled_field.dart';

/// `1.5 Contraseña nueva`.
///
/// **`Guardar la contraseña`, not the design's `Guardar y entrar`.** Better
/// Auth's `reset-password` answers with a status and no session, so the second
/// half of that label would be a promise the call does not keep. Saving is what
/// it does; entering is the next screen's job.
///
/// **No strength meter.** The design draws three segments and a sentence about
/// how strong the password is. Nobody has decided what makes one strong here,
/// and a meter filled by a rule invented at this keyboard would be a figure the
/// product does not stand behind — the same reading as the rating the verdict
/// screens do not print. `CredentialRules.minimumPasswordLength` is the one
/// stated floor, and it is what this screen enforces.
class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({
    super.key,
    required this.onSubmit,
    required this.busy,
    required this.saved,
    required this.onBack,
    required this.onSignIn,
    this.problem,
  });

  final void Function(String password) onSubmit;
  final bool busy;

  /// Whether the provider has accepted the new password.
  final bool saved;

  final VoidCallback onBack;

  /// On to `1.1`. The reset leaves no session behind, so the way in is still
  /// the sign-in form.
  final VoidCallback onSignIn;

  final String? problem;

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final TextEditingController _password = TextEditingController();
  final TextEditingController _again = TextEditingController();
  String? _local;

  @override
  void dispose() {
    _password.dispose();
    _again.dispose();
    super.dispose();
  }

  /// **Both rules are checked here rather than at the provider.** A mismatch is
  /// something only this screen can see — the second field never travels — and
  /// the length floor is `CredentialRules`, restated to the player before a
  /// round trip that could only answer 400.
  void _submit() {
    final String password = _password.text;
    setState(() {
      if (!CredentialRules.longEnough(password)) {
        _local =
            'La contraseña necesita al menos '
            '${CredentialRules.minimumPasswordLength} caracteres.';
      } else if (password != _again.text) {
        _local = 'Las dos contraseñas no son iguales.';
      } else {
        _local = null;
      }
    });
    if (_local == null) {
      widget.onSubmit(password);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? message = _local ?? widget.problem;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DetailHeader(title: 'CONTRASEÑA NUEVA', onBack: widget.onBack),
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
                if (widget.saved) ...<Widget>[
                  Text(
                    'Listo. Ya puedes entrar con tu contraseña nueva.',
                    key: const Key('new-password-done'),
                    style: BrandText.body(),
                  ),
                  const SizedBox(height: BrandShape.space5),
                  BrandButton.primary(
                    label: 'Iniciar sesión',
                    onPressed: widget.onSignIn,
                  ),
                ] else ...<Widget>[
                  LabelledField(
                    label: 'NUEVA',
                    controller: _password,
                    fieldKey: const Key('new-password'),
                    obscure: true,
                    enabled: !widget.busy,
                  ),
                  const SizedBox(height: BrandShape.space3),
                  LabelledField(
                    label: 'OTRA VEZ',
                    controller: _again,
                    fieldKey: const Key('new-password-again'),
                    obscure: true,
                    enabled: !widget.busy,
                  ),
                  if (message != null) ...<Widget>[
                    const SizedBox(height: BrandShape.space3),
                    InlineBanner(
                      key: const Key('new-password-problem'),
                      kind: BannerKind.error,
                      message: message,
                    ),
                  ],
                  const SizedBox(height: BrandShape.space5),
                  BrandButton.primary(
                    label: widget.busy ? 'Guardando…' : 'Guardar la contraseña',
                    onPressed: widget.busy ? () {} : _submit,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
