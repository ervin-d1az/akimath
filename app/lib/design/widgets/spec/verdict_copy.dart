import 'verdict.dart';

/// The words a verdict is announced with, in one place.
///
/// **PURE** — a switch over the sealed encoding, no widget and no context.
///
/// **One home, because a legend that teaches a word no screen shows is worse
/// than no legend.** `4.5 Ajustes` used to caption the two marks *Acierto* and
/// *Se torció* while the screens a player actually meets said *¡Bien hecho!*
/// and *Casi* — so the key taught two words the app never uses, to explain two
/// marks by a metaphor ("se torció" — *it got twisted*) about a tail curl the
/// legend does not draw.
///
/// The es-MX is the player's; everything around it stays English.
String verdictHeadline(Verdict verdict) => switch (verdict) {
      Verdict.correct => '¡Bien hecho!',
      // Never a word that names the failure — `req-diagnosis-copy` scans the
      // rendered tree for "incorrecto", "error", "fallaste" and "mal". "Casi"
      // says the same thing about the attempt without saying it about the
      // player.
      Verdict.wrong => 'Casi',
    };

/// What the mark itself looks like, for the key that explains the pair.
///
/// **It describes the shape and not the colour** (BRD-1). A reader who cannot
/// separate green from coral still has to be able to use this legend, and a
/// caption reading "el aro verde" would be the one sentence on the screen that
/// undoes the invariant the marks were designed around.
///
/// It says *línea continua* and *línea punteada* rather than "el aro va
/// cortado": a dashed circle is not a cut one, and naming the thing "el aro"
/// assumes a player already knows the ring is a named part of the app.
String verdictMarkDescription(Verdict verdict) => switch (verdict) {
      Verdict.correct => 'Círculo de línea continua.',
      Verdict.wrong => 'Círculo de línea punteada.',
    };
