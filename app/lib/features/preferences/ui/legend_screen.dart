import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/candy_surface.dart';
import '../../../design/widgets/detail_header.dart';
import '../../../design/widgets/spec/verdict.dart';
import '../../../design/widgets/spec/verdict_copy.dart';
import '../../../design/widgets/verdict_ring.dart';

/// The two marks, side by side, with what each one means.
///
/// **`4.5`'s verdict preview, given the screen it never had.** The design puts
/// it inside *Accesibilidad*, under a `Modo daltonismo` toggle whose own note
/// says the mode *"no cambia el diseño: solo lo hace obvio"* — the encoding is
/// always on (D6), so the toggle has nothing to switch and the preview is the
/// only part of that card with a job.
///
/// It earns its place by teaching the pair somewhere other than mid-round: a
/// learner meets these two marks in the second where they most want to know
/// what happened, which is the worst moment to be learning a convention.
///
/// The two differ by **shape** before they differ by hue — a solid ring against
/// a dashed one — which is the whole reason `Verdict` carries an outline and a
/// glyph and no colour (BRD-1). Shown together so the difference is legible as
/// a difference, which it never is one screen at a time.
class LegendScreen extends StatelessWidget {
  const LegendScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DetailHeader(title: 'CÓMO SE LEEN LOS RETOS', onBack: onBack),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              BrandShape.space4,
              BrandShape.space5,
              BrandShape.space4,
              BrandShape.space4,
            ),
            children: <Widget>[
              CandySurface(
                borderRadius: BrandShape.radiusCardMedium,
                padding: const EdgeInsets.all(BrandShape.space4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _row(Verdict.correct),
                    const SizedBox(height: BrandShape.space4),
                    _row(Verdict.wrong),
                  ],
                ),
              ),
              const SizedBox(height: BrandShape.space4),
              Text(
                'Contorno continuo para acierto, punteado para error. '
                'Nunca solo el color.',
                style: BrandText.caption(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(Verdict verdict) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        VerdictRing(verdict, size: 44),
        const SizedBox(width: BrandShape.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // **The same words the screens use** — from `verdict_copy.dart`,
              // so the key cannot teach a term a player will never meet.
              Text(verdictHeadline(verdict), style: BrandText.cardTitle()),
              const SizedBox(height: 2),
              Text(verdictMarkDescription(verdict), style: BrandText.caption()),
            ],
          ),
        ),
      ],
    );
  }
}
