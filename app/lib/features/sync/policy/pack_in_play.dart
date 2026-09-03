/// Which pack this device is playing right now, and whether it may be played.
///
/// **PURE** — two packs and a moment in, one of three answers out. No socket,
/// no storage, no clock.
///
/// **It exists because two roots were answering it differently.** Inicio and
/// Mapa both resolved *the issued pack, or else the bundled one* and both read
/// the same file, and only one of them asked whether the window had closed —
/// so the day `assets/packs/starter.json` lapses, Inicio refuses to play and
/// Mapa draws a full map of topics with a live `Practicar 5 retos` on every one
/// of them. One app, two answers, and the one that let you play was wrong.
///
/// `packRefresh` is the sibling decision and the reason this lives beside it:
/// that one answers *should I ask the server for another pack*, this one
/// answers *which pack am I playing while I wait*. Neither belongs to a screen.
library;

import '../../../api/sync.dart';
import '../../../content/model/issued_pack.dart';
import '../../../content/model/pack.dart';

/// The answer.
sealed class PackInPlay {
  const PackInPlay();
}

/// Play this one.
final class PackReady extends PackInPlay {
  const PackReady(this.pack);

  final Pack pack;
}

/// Nothing has been read yet — neither the bundled pack nor an issued one.
///
/// A launch state and not a refusal: the caller draws whatever it draws while
/// it waits, and asks again when a pack lands.
final class PackPending extends PackInPlay {
  const PackPending();
}

/// The pack's window has closed, so there is nothing to play.
final class PackLapsed extends PackInPlay {
  const PackLapsed();

  /// What a player is told, in one place, so two roots cannot word it
  /// differently — or, as they did, one of them not at all.
  String get message =>
      'Estos retos ya vencieron. Conéctate para recibir nuevos.';
}

/// Which pack is in play at [now].
///
/// **The issued pack replaces the bundled one where there is one** — same six
/// families, same boards, and every item carrying a `(packId, index)` the
/// server can grade. So a lapsed *issued* pack is lapsed, full stop: it does
/// not fall back to the bundled pack underneath it. That is the behaviour both
/// roots were built on and this change deliberately does not reopen it —
/// `packRefresh` is what asks for a replacement, and falling back here would
/// hand a player items whose answers no attempt can be addressed to.
///
/// [now] may be in any zone. [Pack.isExpiredAt] compares absolute instants, so
/// the same moment written two ways gives the same answer and a caller does not
/// have to remember to convert.
PackInPlay packInPlay({
  required Pack? issued,
  required Pack? bundled,
  required DateTime now,
}) {
  final Pack? pack = issued ?? bundled;
  if (pack == null) {
    return const PackPending();
  }
  if (pack.isExpiredAt(now)) {
    return const PackLapsed();
  }
  return PackReady(pack);
}

/// The pack inside what the server issued, or null when this app cannot read
/// it.
///
/// **A pack this app cannot read is a pack it does not play**, which is the
/// rule `PackReader` already keeps where the bundled one is read. Both roots
/// adopted an issued pack and both wrote this `try`/`on FormatException` out by
/// hand; a reader that swallowed the exception in one of them and not the other
/// is a crash on a fetch nobody asked for.
Pack? packFrom(IssuedPack issued) {
  try {
    return readIssuedPack(
      Map<String, dynamic>.from(issued.pack),
      packId: issued.packId,
      issuedAt: issued.issuedAt,
      expiresAt: issued.expiresAt,
    );
  } on FormatException {
    // Nothing to say to a player about a request they did not make.
    return null;
  }
}
