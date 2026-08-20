import '../../../api/me_result.dart';
import '../../states/policy/account_state.dart';

/// What the erasure flow is showing, as one closed set.
///
/// **PURE** — a result in, a step and its words out. No widget, no clock, no
/// socket.
///
/// It exists for the same reason [AccountState] does: a screen that switches on
/// `EraseResult` inline decides copy in four places and misses the two that are
/// not results at all — the confirmation before anything is sent, and the wait
/// while it is in flight.
enum ErasureStep {
  /// The request is out and nothing has come back.
  erasing,

  /// There is nothing left on the server. Both a 204 and a 404 land here.
  gone,

  /// The session was refused. Nothing was erased and this token never will.
  rejected,

  /// Nothing answered.
  offline,

  /// An answer arrived and it was not one this client can read.
  serverError,
}

/// The step an erasure attempt put the flow in.
///
/// `null` is the wait, the same shape as [accountStateFor] — the absence of a
/// result is a state a screen has to draw, and it is not one the union can
/// carry.
ErasureStep erasureStepFor(EraseResult? result) => switch (result) {
  null => ErasureStep.erasing,
  // **Two facts, one outcome.** A developer reading a log wants to know whether
  // there was a row; the player asked for there to be nothing left, and there
  // is nothing left. Collapsed here rather than in a screen.
  EraseDone() || EraseNothingThere() => ErasureStep.gone,
  EraseRejected() => ErasureStep.rejected,
  EraseFailed() => ErasureStep.serverError,
  EraseUnreachable() => ErasureStep.offline,
};

/// Whether trying again could answer differently.
///
/// A refused session does not recover by being sent twice, and there is nothing
/// to erase a second time — offering a retry on either teaches the player that
/// the button is decoration.
bool canRetryErasure(ErasureStep step) => switch (step) {
  ErasureStep.offline || ErasureStep.serverError => true,
  ErasureStep.erasing || ErasureStep.gone || ErasureStep.rejected => false,
};

/// Whether the door is offered at all, given where the account stands.
///
/// Only where this device holds a session the server accepts. [AccountState
/// .noPlayer] counts: there may be nothing on the server, and the act still
/// means something — it is how a device stops being attached to an account.
bool erasureOffered(AccountState state) => switch (state) {
  AccountState.linked || AccountState.noPlayer => true,
  AccountState.none ||
  AccountState.loading ||
  AccountState.rejected ||
  AccountState.offline ||
  AccountState.serverError ||
  // The account belongs to another device's player; there is nothing of this
  // one's to erase, and the request would be about somebody else's row.
  AccountState.otherDevice => false,
};

/// The label on the door, in Ajustes.
const String erasureDoorLabel = 'Borrar mis datos';

/// The question, asked before anything is sent.
const String erasureConfirmHeadline = '¿Borrar tus datos?';

/// What the question is actually asking, spelled out.
///
/// **It names what survives.** The server erases the player and everything
/// referencing them; the account itself belongs to the identity provider and is
/// not ours to delete, so the address still exists afterwards and the player
/// would find that out by signing in. Saying so here costs one sentence.
const String erasureConfirmDetail =
    'Se borra todo lo que guardamos de ti y este teléfono deja de estar '
    'ligado a tu cuenta. Tu correo sigue registrado con quien nos lleva las '
    'cuentas. Lo que jugaste aquí se queda en este teléfono.';

/// Yes, and it is the word for the act rather than for agreement.
const String erasureConfirmYes = 'Sí, borrar';

/// No, and it is a way out rather than a failure.
const String erasureConfirmNo = 'Mejor no';

/// The headline for a step. Every step has one, and no two share it.
String erasureHeadline(ErasureStep step) => switch (step) {
  ErasureStep.erasing => 'Borrando…',
  ErasureStep.gone => 'Listo, ya no queda nada',
  ErasureStep.rejected => 'Tu sesión ya no sirve',
  ErasureStep.offline => 'Sin conexión',
  ErasureStep.serverError => 'Algo falló de nuestro lado',
};

/// The line under the headline.
String erasureDetail(ErasureStep step) => switch (step) {
  ErasureStep.erasing => 'Un momento.',
  ErasureStep.gone =>
    'Tu correo sigue registrado con quien nos lleva las cuentas. Este teléfono '
        'ya no está ligado a nada.',
  ErasureStep.rejected => 'Vuelve a entrar a tu cuenta y pídelo otra vez.',
  ErasureStep.offline => 'No se pudo borrar. Inténtalo cuando haya señal.',
  // **It does not claim to know.** A 500 can arrive after the delete committed,
  // so "no se borró nada" would be a guess dressed as a fact.
  ErasureStep.serverError => 'No pudimos confirmar que se borrara. Inténtalo otra vez.',
};
