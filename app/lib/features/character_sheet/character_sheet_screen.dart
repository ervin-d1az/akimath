import 'package:flutter/material.dart';

import '../../design/brand/aki.dart';
import '../../design/brand/app_icon.dart';
import '../../design/tokens/tokens.dart';
import '../../design/widgets/candy_surface.dart';
import '../../design/widgets/speech_bubble.dart';

/// A live rendering of `Aki Hoja de Personaje.dc.html`.
///
/// Aki carries one job the artwork has to make possible: a part of her that can
/// be **lost and come back**. On the axolotl it was a gill; on Aki it is the
/// curl of her tail — it comes undone on a wrong answer and grows back green.
/// Nothing else about her moves: she does not scold, does not look let down,
/// and does not appear while the user is solving.
class CharacterSheetScreen extends StatelessWidget {
  const CharacterSheetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.sand,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 72),
          children: <Widget>[
            Text('AKI · LA MASCOTA', style: BrandText.sectionTitle(size: 42)),
            const SizedBox(height: BrandShape.space2),
            Text(
              'Mismo modelo calcomanía · misma paleta · la cola enroscada '
              'hereda el trabajo de la branquia',
              style: BrandText.body(color: BrandColors.muted),
            ),
            const SizedBox(height: BrandShape.space7),
            Text('HOJA DE PERSONAJE', style: BrandText.sectionTitle()),
            const SizedBox(height: BrandShape.space4),
            const _Poses(),
            const SizedBox(height: BrandShape.space7),
            Text(
              'ÍCONO, CONTEXTO Y PENDIENTES',
              style: BrandText.sectionTitle(),
            ),
            const SizedBox(height: BrandShape.space4),
            const _IconAndContext(),
          ],
        ),
      ),
    );
  }
}

class _Poses extends StatelessWidget {
  const _Poses();

  /// The three poses, each with the copy that explains what changed.
  static const List<(AkiPose, String, String)> _sheet =
      <(AkiPose, String, String)>[
    (
      AkiPose.base,
      'En calma',
      'Cabeza ancha, hocico oscuro de una pieza, cejas y arruga de tinta, '
          'orejas dobladas, collar rosa y la cola enroscada.',
    ),
    (
      AkiPose.correct,
      'Al acertar',
      'Orejas arriba, sonrisa más ancha y la cola moviéndose con dos rayitas. '
          'Ni confeti ni estrellitas.',
    ),
    (
      AkiPose.slip,
      'Al fallar',
      'Se le desenrosca la cola y ya le está saliendo el rizo nuevo, en verde. '
          'Se agacha un poco; nunca pone cara triste.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: BrandShape.space6,
      runSpacing: BrandShape.space6,
      children: <Widget>[
        for (final (AkiPose pose, String title, String note) in _sheet)
          CandySurface.card(
            width: 390,
            padding: const EdgeInsets.fromLTRB(28, 26, 28, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  height: 290,
                  child: Center(child: Aki(width: 290, pose: pose)),
                ),
                const SizedBox(height: BrandShape.space3),
                Text(title, style: BrandText.cardTitle()),
                const SizedBox(height: BrandShape.space2),
                Text(
                  note,
                  textAlign: TextAlign.center,
                  style: BrandText.caption(),
                ),
              ],
            ),
          ),
        const _Inheritance(),
      ],
    );
  }
}

/// What carries over from the axolotl, and what the palette is now.
class _Inheritance extends StatelessWidget {
  const _Inheritance();

  static const List<(String, Color, Color)> _swatches =
      <(String, Color, Color)>[
    ('CUERPO #F7DFB6', BrandColors.akiCoat, BrandColors.ink),
    ('HOCICO #4A4060', BrandColors.akiMuzzle, BrandColors.surface),
    ('OREJAS #332B44', BrandColors.akiEars, BrandColors.surface),
    ('COLLAR #E85E92', BrandColors.pink, BrandColors.surface),
  ];

  @override
  Widget build(BuildContext context) {
    return CandySurface.card(
      background: BrandColors.yellow,
      width: 420,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('LO QUE SE HEREDA', style: BrandText.sectionTitle(size: 28)),
          const SizedBox(height: BrandShape.space3),
          Text(
            'El gesto de error necesita una parte del cuerpo que se pueda '
            'perder y volver. En el ajolote era la branquia; en Aki es el rizo '
            'de la cola: se desenrosca al fallar y vuelve a enroscarse en verde.',
            style: BrandText.body(),
          ),
          const SizedBox(height: BrandShape.space3),
          Container(height: 2.5, color: BrandColors.ink),
          const SizedBox(height: BrandShape.space3),
          Text(
            'Lo demás no se mueve: no regaña, no se ve decepcionada, no aparece '
            'mientras resuelves y dice una línea corta, nunca la misma dos veces.',
            style: BrandText.body(),
          ),
          const SizedBox(height: BrandShape.space4),
          Wrap(
            spacing: BrandShape.space2,
            runSpacing: BrandShape.space2,
            children: <Widget>[
              for (final (String label, Color fill, Color ink) in _swatches)
                CandySurface(
                  background: fill,
                  borderRadius: 12,
                  borderWidth: 2.5,
                  shadowOffset: Offset.zero,
                  minHeight: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  alignment: Alignment.center,
                  child: Text(label, style: BrandText.eyebrow(color: ink)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconAndContext extends StatelessWidget {
  const _IconAndContext();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: BrandShape.space6,
      runSpacing: BrandShape.space6,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: const <Widget>[
        _IconCard(),
        _Fragments(),
        _StillToDecide(),
      ],
    );
  }
}

class _IconCard extends StatelessWidget {
  const _IconCard();

  @override
  Widget build(BuildContext context) {
    return CandySurface.card(
      width: 470,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('ÍCONO · LA CARA SOBRE EL VERDE', style: BrandText.eyebrow()),
          const SizedBox(height: BrandShape.space5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: BrandShape.space5,
            children: <Widget>[
              const AkiAppIcon(size: 210),
              Column(
                mainAxisSize: MainAxisSize.min,
                spacing: BrandShape.space3,
                children: <Widget>[
                  for (final double size in <double>[60, 40])
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        AkiAppIcon(size: size, withShadow: false),
                        const SizedBox(height: BrandShape.space1),
                        Text(
                          '${size.toInt()} px',
                          style: BrandText.caption(),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: BrandShape.space5),
          Text(
            'El hocico oscuro le da algo que el ajolote no tenía: contraste '
            'dentro de la propia cara. A 40 px todavía se distingue de '
            'cualquier otro ícono.',
            style: BrandText.body(),
          ),
        ],
      ),
    );
  }
}

/// Two moments from the real product, so the character is judged in context
/// rather than as a sticker on a white card.
class _Fragments extends StatelessWidget {
  const _Fragments();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: BrandShape.space5,
        children: <Widget>[
          CandySurface.card(
            background: BrandColors.cream,
            padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('FRAGMENTO · INICIO', style: BrandText.eyebrow()),
                const SizedBox(height: BrandShape.space3),
                const _Beat(
                  pose: AkiPose.base,
                  line: 'Traigo dos fracciones que no se parecen.',
                ),
              ],
            ),
          ),
          CandySurface.card(
            background: BrandColors.cream,
            padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('FRAGMENTO · ERROR', style: BrandText.eyebrow()),
                const SizedBox(height: BrandShape.space3),
                const _Beat(
                  pose: AkiPose.slip,
                  line: 'Se me desenroscó la cola. Ya vuelve.',
                ),
                const SizedBox(height: BrandShape.space3),
                // The diagnosis is separate from what Aki says: she never
                // explains the mistake, the app does.
                CandySurface(
                  background: BrandColors.coral,
                  borderRadius: 18,
                  shadowOffset: Offset.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Text(
                    'Sumaste los denominadores. El 20 se queda como está.',
                    style: BrandText.body(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Beat extends StatelessWidget {
  const _Beat({required this.pose, required this.line});

  final AkiPose pose;
  final String line;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      spacing: BrandShape.space2,
      children: <Widget>[
        Aki(width: 165, pose: pose),
        Flexible(child: SpeechBubble(text: line)),
      ],
    );
  }
}

class _StillToDecide extends StatelessWidget {
  const _StillToDecide();

  @override
  Widget build(BuildContext context) {
    return CandySurface.card(
      width: 420,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('LO QUE FALTA DECIDIR', style: BrandText.sectionTitle(size: 26)),
          const SizedBox(height: BrandShape.space3),
          Text(
            'El nombre AmbysMath venía de Ambystoma mexicanum, el ajolote. Con '
            'la perrita esa parte se rehace: el código ya quedó en AkiMath, '
            'falta confirmarlo en tiendas y en los repos.',
            style: BrandText.body(),
          ),
          const SizedBox(height: BrandShape.space3),
          Container(height: 2.5, color: BrandColors.rule),
          const SizedBox(height: BrandShape.space3),
          Text(
            'El gesto de error quedó resuelto con la cola. La otra opción era '
            'voltearle una oreja, pero “perder y recuperar” se lee mejor en la '
            'cola.',
            style: BrandText.body(),
          ),
          const SizedBox(height: BrandShape.space3),
          Container(height: 2.5, color: BrandColors.rule),
          const SizedBox(height: BrandShape.space3),
          Text(
            'Las 50 pantallas, el logotipo y el ícono se cambian de un jalón '
            'cuando confirmes. El personaje ya no se vuelve a tocar.',
            style: BrandText.body(),
          ),
        ],
      ),
    );
  }
}
