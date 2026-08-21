/// What to do about the pack this device holds, on a launch.
///
/// **PURE** — a stored id and a clock in, one of three answers out. No socket,
/// no storage.
///
/// It exists because the decision has three branches and each of them is a
/// request or the absence of one, which is exactly the sort of thing that grows
/// a fourth branch inside a `Future` chain where nobody can see it.
library;

/// What the device should do next.
enum PackRefresh {
  /// Nothing: there is no session, so there is no pack and nothing to ask.
  ///
  /// Unlinked play is entirely offline (ADR 0002) — the bundled pack is the
  /// whole of it, for ever and by design.
  none,

  /// Ask for a new one. Either this device has never been issued a pack, or the
  /// one it holds has lapsed past its window.
  issue,

  /// Fetch the one whose id is stored. The server rebuilds it byte for byte,
  /// so this is the same pack and not a new one.
  fetch,
}

/// The decision.
///
/// [expiresAt] is what the *device* last knew about the stored pack, or null
/// when it knows nothing — a fresh install, or a store that could not be read.
/// A lapsed pack is issued rather than fetched, because the server would refuse
/// it anyway and a round trip to be told so is a round trip.
///
/// **A pack expiring in the next minute counts as lapsed.** The window is
/// measured in weeks; handing a player a pack that dies mid-series to save one
/// request is the wrong trade, and the boundary has to fall somewhere.
PackRefresh packRefresh({
  required bool hasSession,
  required String? storedPackId,
  required DateTime? expiresAt,
  required DateTime now,
}) {
  if (!hasSession) {
    return PackRefresh.none;
  }
  if (storedPackId == null || storedPackId.isEmpty) {
    return PackRefresh.issue;
  }
  if (expiresAt != null && !expiresAt.isAfter(now.add(expiryMargin))) {
    return PackRefresh.issue;
  }
  return PackRefresh.fetch;
}

/// How close to its end a pack is treated as already over.
const Duration expiryMargin = Duration(minutes: 1);
