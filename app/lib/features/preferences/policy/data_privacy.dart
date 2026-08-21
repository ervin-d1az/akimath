/// The two things `4.7 Datos y privacidad` offers, and what each one can say
/// today.
///
/// **PURE** — a closed set of copy, so the screen holds no sentences of its own
/// and a test can read the words without a widget tree.
///
/// **Neither can be requested yet, and the reason differs.** Export is not one
/// of the contracted operations at all — there is no endpoint to call.
/// Erasing *only* the history is not one either: `DELETE /me` removes the
/// player and everything under it, which is a different act, already has its
/// own screen, and is reached from `4.3 Cuenta`. So both cards keep the words
/// the design gives them and neither draws a button, because a control that
/// produces nothing reads as broken rather than as unbuilt (DR-P2).
enum DataRequest {
  /// *Descargar mis datos*.
  export(
    title: 'Descargar mis datos',
    description: 'Un archivo con tus respuestas, tus tiempos y tu historial. '
        'Llega por correo en unos minutos.',
    unavailable: 'Todavía no podemos armar ese archivo. Cuando se pueda, va a '
        'estar aquí.',
  ),

  /// *Borrar mi historial*.
  eraseHistory(
    title: 'Borrar mi historial',
    description: 'Se van las respuestas y los tiempos. Tu rating y tu racha se '
        'quedan.',
    unavailable: 'Todavía no se puede borrar solo el historial. Cuando se '
        'pueda, va a estar aquí.',
  );

  const DataRequest({
    required this.title,
    required this.description,
    required this.unavailable,
  });

  /// The card's heading, verbatim from the design.
  final String title;

  /// What the request would do, verbatim from the design.
  final String description;

  /// Why it cannot be made today. In place of the button rather than beside
  /// it: the sentence is the honest half of what the button claimed.
  final String unavailable;
}
