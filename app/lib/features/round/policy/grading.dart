import '../../../content/model/item.dart';
import '../../../design/widgets/spec/verdict.dart';

/// Whether [answer] solves [item].
///
/// Pure: two values in, a verdict out. No clock, no network, no storage.
///
/// Offline this is the whole of grading, and its verdict is **provisional until
/// sync** — `ARCHITECTURE.md` §4. It compares canonical forms rather than raw
/// text so that the client and the server cannot disagree about what the player
/// meant: the canonicalisation rules are the ones `packages/contract` froze.
Verdict grade(Item item, String answer) =>
    _canonical(answer) == _canonical(item.expected)
        ? Verdict.correct
        : Verdict.wrong;

/// U+002D HYPHEN-MINUS folded to U+2212 MINUS SIGN.
///
/// The keypad cannot emit a hyphen — `keypad_layout.dart` sees to that — but a
/// hand-written fixture or a future paste path can, and a verdict that turned on
/// which dash was typed would be the worst kind of wrong.
String _canonical(String value) => value.trim().replaceAll('-', '−');
