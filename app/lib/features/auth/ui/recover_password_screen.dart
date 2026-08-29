import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/brand_button.dart';
import '../../../design/widgets/detail_header.dart';
import '../../shell/policy/banner_visual.dart';
import '../../shell/ui/inline_banner.dart';
import '../policy/credential_rules.dart';
import 'labelled_field.dart';

/// `Recuperar · correo`.
///
/// **The confirmation is conditional, and that is not hedging.** Better Auth
/// answers `forget-password` the same way whether or not an account exists at
/// the address, on purpose — a caller that could tell the difference could
/// enumerate who is registered. So the screen can honestly say a link is on its
/// way *if that account exists*, and cannot honestly say more. The design's
/// *"TE MANDAMOS UN ENLACE"* is the heading, where it is a promise about what
/// the button does; the sentence after the call is what the provider actually
/// licenses.
///
/// **Nothing is claimed before the call returns.** A "sent" state set
/// optimistically would survive a provider with no reset mailer configured,
/// which answers with a refusal — and that refusal is shown, in the provider's
/// own words, exactly as `1.2` and `1.1` show theirs.
class RecoverPasswordScreen extends StatefulWidget {
  const RecoverPasswordScreen({
    super.key,
    required this.onSubmit,
    required this.busy,
    required this.sent,
    required this.onBack,
    this.initialEmail = '',
    this.problem,
  });

  final void Function(String email) onSubmit;
  final bool busy;

  /// Whether the provider has accepted the request. Set from the answer, never
  /// before it.
  final bool sent;

  /// Back to `1.1`, which is the only screen this one is reached from.
  final VoidCallback onBack;

  final String initialEmail;
  final String? problem;

  @override
  State<RecoverPasswordScreen> createState() => _RecoverPasswordScreenState();
}

class _RecoverPasswordScreenState extends State<RecoverPasswordScreen> {
  late final TextEditingController _email = TextEditingController(
    text: widget.initialEmail,
  );
  String? _local;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    final String email = _email.text.trim();
    setState(() {
      _local = CredentialRules.looksLikeEmail(email)
          ? null
          : 'Revisa el correo.';
    });
    if (_local == null) {
      widget.onSubmit(email);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? message = _local ?? widget.problem;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DetailHeader(title: 'TE MANDAMOS UN ENLACE', onBack: widget.onBack),
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
                  'Escribe el correo de tu cuenta y te llega en un minuto.',
                  style: BrandText.body(),
                ),
                const SizedBox(height: BrandShape.space4),
                LabelledField(
                  label: 'CORREO',
                  controller: _email,
                  fieldKey: const Key('recover-email'),
                  enabled: !widget.busy && !widget.sent,
                ),
                if (message != null) ...<Widget>[
                  const SizedBox(height: BrandShape.space3),
                  InlineBanner(
                    key: const Key('recover-problem'),
                    kind: BannerKind.error,
                    message: message,
                  ),
                ],
                if (widget.sent) ...<Widget>[
                  const SizedBox(height: BrandShape.space3),
                  Text(
                    'Si esa cuenta existe, el enlace ya va en camino. Ábrelo '
                    'desde tu correo para poner una contraseña nueva.',
                    key: const Key('recover-sent'),
                    style: BrandText.body(),
                  ),
                ],
                const SizedBox(height: BrandShape.space5),
                if (!widget.sent)
                  BrandButton.primary(
                    label: widget.busy ? 'Enviando…' : 'Enviar el enlace',
                    onPressed: widget.busy ? () {} : _submit,
                  ),
                const SizedBox(height: BrandShape.space3),
                BrandButton.secondary(
                  label: 'Volver a iniciar sesión',
                  onPressed: widget.onBack,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
