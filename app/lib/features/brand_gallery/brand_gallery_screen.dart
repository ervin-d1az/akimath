import 'package:flutter/material.dart';

import '../../design/brand/app_icon.dart';
import '../../design/brand/brand_lockup.dart';
import '../../design/tokens/tokens.dart';
import '../../design/widgets/candy_surface.dart';
import '../splash/splash_screen.dart';

/// A live rendering of `AkiMath Marca.dc.html`.
///
/// It exists so the implemented brand can be compared against the design doc by
/// eye, and so the golden tests have a single screen that exercises every piece
/// of the brand layer at once. It ships nowhere near the real app.
class BrandGalleryScreen extends StatelessWidget {
  const BrandGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.sand,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 64),
          children: <Widget>[
            Text('AKIMATH · MARCA', style: BrandText.sectionTitle(size: 40)),
            const SizedBox(height: BrandShape.space2),
            Text(
              'Logotipo, ícono y splash · el sistema visual no cambia',
              style: BrandText.body(color: BrandColors.muted),
            ),
            const SizedBox(height: BrandShape.space7),
            const _Section(
              title: 'LOGOTIPO',
              note: 'Darumadrop One · “Math” en rosa · Darumadrop One',
              noteBackground: BrandColors.surface,
              child: _Lockups(),
            ),
            const SizedBox(height: BrandShape.space7),
            const _Section(
              title: 'ÍCONO DE APP',
              note: 'Sin texto · la cara y el hocico oscuro',
              noteBackground: BrandColors.yellow,
              child: _IconOptions(),
            ),
            const SizedBox(height: BrandShape.space7),
            const _Section(
              title: 'PANTALLA DE CARGA',
              note: 'Sin partículas · tres puntos y ya',
              noteBackground: BrandColors.surface,
              child: _SplashPreviews(),
            ),
            const SizedBox(height: BrandShape.space7),
            const _LogoRules(),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.note,
    required this.noteBackground,
    required this.child,
  });

  final String title;
  final String note;
  final Color noteBackground;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: BrandShape.space3,
          runSpacing: BrandShape.space2,
          children: <Widget>[
            Text(title, style: BrandText.sectionTitle()),
            CandySurface.pill(
              background: noteBackground,
              child: Text(note, style: BrandText.eyebrow(color: BrandColors.ink)),
            ),
          ],
        ),
        const SizedBox(height: BrandShape.space4),
        child,
      ],
    );
  }
}

class _Lockups extends StatelessWidget {
  const _Lockups();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: BrandShape.space6,
      runSpacing: BrandShape.space6,
      children: <Widget>[
        _Sample(
          eyebrow: 'COMPLETA CON AKI · SPLASH Y TIENDAS',
          background: BrandColors.cream,
          caption: 'Aki centrado sobre el wordmark. Es la única versión donde '
              'el personaje va grande.',
          child: BrandLockup(
            variant: BrandLockupVariant.fullWithAki,
            scale: 0.62,
          ),
        ),
        _Sample(
          eyebrow: 'COMPLETA SIN AKI · DOCUMENTOS Y PIE DE PÁGINA',
          background: BrandColors.cream,
          caption: 'El descriptor va en Plus Jakarta con mucho tracking, nunca '
              'en Darumadrop.',
          child: BrandLockup(
            variant: BrandLockupVariant.fullWithoutAki,
            scale: 0.62,
          ),
        ),
        _Sample(
          eyebrow: 'COMPACTA CON AKI · ENCABEZADOS DE APP',
          caption: 'La cara entra en la tarjeta verde de 64 px; sirve como '
              'avatar y como marca.',
          child: BrandLockup(variant: BrandLockupVariant.compactWithAki),
        ),
        _Sample(
          eyebrow: 'COMPACTA SIN AKI · BARRAS Y CORREOS',
          caption: 'Mínimo 28 px de alto de letra: abajo de eso la Darumadrop '
              'pierde su remate redondo.',
          child: BrandLockup(variant: BrandLockupVariant.compactWithoutAki),
        ),
      ],
    );
  }
}

class _IconOptions extends StatelessWidget {
  const _IconOptions();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: BrandShape.space6,
      runSpacing: BrandShape.space6,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: <Widget>[
        const _Sample(
          eyebrow: 'OPCIÓN A · FONDO CREMA',
          caption: 'Crema sobre crema no separa nada: a 40 px la cabeza se '
              'disuelve en el cuadro.',
          child: _IconRow(background: AppIconBackground.cream),
        ),
        const _Sample(
          eyebrow: 'OPCIÓN B · FONDO VERDE',
          caption: 'El verde recorta la silueta y el hocico oscuro da contraste '
              'dentro de la propia cara.',
          child: _IconRow(background: AppIconBackground.brandGreen),
        ),
        CandySurface.card(
          background: BrandColors.yellow,
          width: 360,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'LA QUE SOBREVIVE ES LA B',
                style: BrandText.sectionTitle(size: 28),
              ),
              const SizedBox(height: BrandShape.space3),
              Text(
                'El verde da el contraste que el crema no puede dar. Además el '
                'ícono queda distinto del fondo de la app: crema es el lienzo '
                'de las pantallas, verde es la marca en la pantalla de inicio '
                'del teléfono.',
                style: BrandText.body(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IconRow extends StatelessWidget {
  const _IconRow({required this.background});

  final AppIconBackground background;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AkiAppIcon(size: 200, background: background),
        const SizedBox(height: BrandShape.space5),
        Text('TAMAÑO REAL EN PANTALLA', style: BrandText.eyebrow()),
        const SizedBox(height: BrandShape.space3),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          spacing: BrandShape.space5,
          children: <Widget>[
            for (final double size in <double>[60, 40])
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  AkiAppIcon(
                    size: size,
                    background: background,
                    withShadow: false,
                  ),
                  const SizedBox(height: BrandShape.space2),
                  Text('${size.toInt()} px', style: BrandText.caption()),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _SplashPreviews extends StatelessWidget {
  const _SplashPreviews();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: BrandShape.space7,
      runSpacing: BrandShape.space7,
      children: <Widget>[
        for (final SplashVariant variant in SplashVariant.values)
          _PhoneFrame(child: SplashScreen(variant: variant)),
      ],
    );
  }
}

/// A 390×844 window onto a real screen widget, so previews and the shipped
/// screen can never drift apart.
class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 390,
      height: 844,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(BrandShape.radiusScreen),
        border: Border.all(
          color: BrandColors.ink,
          width: BrandShape.borderWidth,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: BrandColors.ink,
            offset: BrandShape.shadowCard,
            blurRadius: 0,
          ),
        ],
      ),
      child: MediaQuery(
        data: const MediaQueryData(size: Size(390, 844)),
        child: child,
      ),
    );
  }
}

class _LogoRules extends StatelessWidget {
  const _LogoRules();

  static const List<(Color, String)> _rules = <(Color, String)>[
    (
      BrandColors.pink,
      'Una sola palabra, sin apóstrofo y sin espacio: AkiMath. La “M” en '
          'mayúscula es lo que separa las dos mitades.',
    ),
    (
      BrandColors.green,
      '“Math” en rosa sobre fondos claros; en blanco cuando el fondo es el '
          'verde de marca. Nunca dos colores de acento a la vez.',
    ),
    (
      BrandColors.yellow,
      'El wordmark no lleva contorno ni sombra: la sombra dura es de los '
          'objetos con cuerpo — tarjetas, botones, el cuadro del ícono.',
    ),
    (
      BrandColors.ink,
      'Aki acompaña solo en splash, tiendas y encabezado. Dentro de la app no '
          'se repite junto al wordmark.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return CandySurface.card(
      width: 460,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text('REGLAS DEL LOGOTIPO', style: BrandText.sectionTitle(size: 26)),
          const SizedBox(height: BrandShape.space4),
          for (final (Color swatch, String rule) in _rules)
            Padding(
              padding: const EdgeInsets.only(bottom: BrandShape.space3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: swatch,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: BrandColors.ink,
                        width: BrandShape.borderWidth,
                      ),
                    ),
                  ),
                  const SizedBox(width: BrandShape.space3),
                  Expanded(child: Text(rule, style: BrandText.body())),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A labelled card wrapping one brand sample, mirroring the design doc's cards.
class _Sample extends StatelessWidget {
  const _Sample({
    required this.eyebrow,
    required this.caption,
    required this.child,
    this.background = BrandColors.surface,
  });

  final String eyebrow;
  final String caption;
  final Widget child;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return CandySurface.card(
      background: background,
      width: 460,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(eyebrow, style: BrandText.eyebrow()),
          const SizedBox(height: BrandShape.space5),
          // Preview chrome scales to fit its card; the brand components never
          // shrink themselves. A lockup that is wider than this card is a fact
          // about the card, not a licence to shrink the wordmark.
          Center(child: FittedBox(fit: BoxFit.scaleDown, child: child)),
          const SizedBox(height: BrandShape.space5),
          Text(caption, style: BrandText.caption()),
        ],
      ),
    );
  }
}
