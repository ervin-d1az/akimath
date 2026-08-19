import 'package:akimath_app/design/widgets/spec/verdict.dart';
import 'package:akimath_app/design/widgets/spec/verdict_copy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the words are plain', () {
    test('neither headline names the failure', () {
      // `req-diagnosis-copy`. "Casi" says something about the attempt without
      // saying it about the player.
      for (final Verdict verdict in Verdict.values) {
        final String headline = verdictHeadline(verdict).toLowerCase();
        for (final String scolding in <String>[
          'incorrecto',
          'error',
          'fallaste',
          'mal',
        ]) {
          expect(headline, isNot(contains(scolding)));
        }
      }
    });

    test('the two headlines differ', () {
      expect(verdictHeadline(Verdict.correct),
          isNot(verdictHeadline(Verdict.wrong)));
    });

    test('the mark descriptions name the shape and not the colour', () {
      // BRD-1. A caption reading "el aro verde" would be the one sentence on
      // the screen that undoes the invariant the marks were designed around.
      for (final Verdict verdict in Verdict.values) {
        final String text = verdictMarkDescription(verdict).toLowerCase();
        for (final String hue in <String>[
          'verde',
          'rojo',
          'coral',
          'rosa',
          'color',
        ]) {
          expect(text, isNot(contains(hue)), reason: '"$hue" appeared');
        }
        expect(text, contains('línea'));
      }
    });

    test('they describe the outline each verdict actually draws', () {
      // Not just "any two different sentences": the solid ring must be the one
      // called continuous.
      expect(Verdict.correct.outline, VerdictOutline.solid);
      expect(verdictMarkDescription(Verdict.correct), contains('continua'));

      expect(Verdict.wrong.outline, VerdictOutline.dashed);
      expect(verdictMarkDescription(Verdict.wrong), contains('punteada'));
    });

    test('no description uses the metaphor the legend used to', () {
      // "El aro va cortado" described a dashed circle as a cut one, and named
      // the ring as if a player already knew it had a name.
      for (final Verdict verdict in Verdict.values) {
        final String text = verdictMarkDescription(verdict).toLowerCase();
        expect(text, isNot(contains('aro')));
        expect(text, isNot(contains('cortad')));
        expect(text, isNot(contains('torc')));
      }
    });
  });
}
