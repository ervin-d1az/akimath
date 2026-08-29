/// What the app says to somebody it will not open an account for.
///
/// **PURE** — constants and one interpolation. No widget, no clock, no socket.
/// It sits beside the decision that produces it for the same reason
/// `policy/erasure.dart` holds the erasure wording: the screen is the adapter
/// that draws these, and a test can pin the claim without a widget tree.
///
/// **PROVISIONAL — this copy is a proposal, not the design's.** No document in
/// the Claude Design project draws a refusal; the `claude_design` MCP is not
/// connected in the session that wrote this, so nothing could be transcribed.
/// The register is taken from the screens that already exist — `policy/erasure
/// .dart`'s confirmation and `age_gate_screen.dart`'s own explanation — and the
/// design owner replaces these strings without touching anything else, because
/// nothing but `AdultsOnlyScreen` reads them. `tasks.md` 0.2 is the item.
///
/// **Every sentence below is true on both ways in**, which is the constraint
/// that shaped them (LANG-2). The refusal is reached from the account door,
/// where the player typed a date and nothing has been sent; and from the
/// sign-in door, where `GET /me` answered with a band the server already stored,
/// so an account and a provider session already exist. A sentence about the
/// date having stayed on the phone would be strange on the second — that player
/// typed no date — and a sentence claiming nothing was sent would be false
/// there. Neither is here.
library;

import 'age_gate.dart';

/// Why, in the fewest words that are still a reason rather than a verdict.
///
/// **It names the product's rule, not the player.** *"No eres elegible"* makes
/// the sentence about the person; this one is about what AkiMath does, which is
/// the same distinction Aki's tone rule draws — she does not scold.
const String adultsOnlyHeadline = 'Las cuentas son para mayores de edad';

/// What follows from it, and what stays true anyway.
///
/// **The age is interpolated rather than typed**, the same construction as
/// `erasureConfirmPrompt` naming `erasureConfirmWord`: the sentence and the
/// threshold cannot come apart, so moving [AgeGate.adultAge] moves the copy.
///
/// **The clause about this phone is load-bearing and easy to drop as padding.**
/// *"y este teléfono no se liga a ninguna"* is what makes the sentence true on
/// the sign-in entry, where the player already has an account and the refusal
/// is that the device will not be attached to it. *"No crea cuentas"* alone
/// would read as false to that player, who is looking at one.
const String adultsOnlyDetail =
    'AkiMath no crea cuentas para menores de ${AgeGate.adultAge} años, y este '
    'teléfono no se liga a ninguna. Puedes seguir jugando: tus retos se '
    'guardan aquí.';

/// The one control, and it goes back to the thing that still works.
///
/// **Nothing else is drawn, and nothing is drawn disabled** (DR-P2). A greyed
/// control reads as broken rather than as closed, and a player cannot tell *not
/// yet* from *not for you* — which is exactly what the screen this replaces got
/// wrong, by offering a tutor's permission the product will never honour.
const String adultsOnlyDoorLabel = 'Volver a los retos';
