/// The id this device answers to, built from bytes it was handed.
///
/// **PURE** — sixteen bytes in, a uuid out. Where the bytes come from is the
/// adapter's, which is what lets this be tested against a fixed sequence
/// instead of against luck.
///
/// **`List<int>` and not `Uint8List`.** The pure-boundary gate allows a policy
/// module no import at all beyond `package:meta`, and `dart:typed_data` is not
/// on the list — correctly, because the list is a closed set that grows by
/// decision rather than by convenience. A list of ints is the same sixteen
/// bytes and asks for nothing.
///
/// **Minted on the device, not issued by the server** (`CLAUDE.md`, ADR 0002):
/// unlinked play is entirely offline and leaves no row anywhere, so there is no
/// request at which the server could hand one over. The id exists before the
/// account does, and linking is what attaches the two.
///
/// **Version 4, and the bits matter.** The frozen `PlayerLink` pins `playerId`
/// to a pattern that requires a version nibble of 1–8 and a variant nibble of
/// 8, 9, a or b. Sixteen random bytes formatted as a uuid fails it about one
/// time in eight, which is the kind of defect that ships and then bites one
/// player in eight.
String playerIdFrom(List<int> bytes) {
  if (bytes.length != 16) {
    throw ArgumentError.value(bytes.length, 'bytes', 'a uuid is sixteen bytes');
  }

  final List<int> value = List<int>.of(bytes);
  // Version 4 in the high nibble of byte 6, and the RFC 4122 variant in the two
  // high bits of byte 8.
  value[6] = (value[6] & 0x0f) | 0x40;
  value[8] = (value[8] & 0x3f) | 0x80;

  final String hex =
      value.map((int b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// The pattern the frozen `PlayerLink` pins `playerId` to.
///
/// Re-derived rather than copied out of `contract/openapi.json`: a copy is a
/// second source of truth, and `test/api/contract_parity_test.dart` runs both
/// over the same probes. The nil and max uuids the contract also allows are
/// deliberately **not** here — this is what a device may *mint*, and neither of
/// those is a random id.
final RegExp _playerId = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

/// Whether a stored string is an id this device could have minted.
///
/// Checked on the way *out* of storage, not only on the way in: a key holding
/// something else — an old format, a truncated write — must produce a fresh id
/// rather than a link request the server refuses with a 400 the player can do
/// nothing about.
bool isPlayerId(String value) => _playerId.hasMatch(value);
