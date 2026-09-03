/// Whether `GET /me/history` is worth asking a second time.
///
/// **PURE** — two counts in, a decision out. No clock, no socket, no widget.
///
/// The screen asks once, when it is built, and the answer it gets is only as
/// good as what the server held at that instant. Measured on 2026-09-02 against
/// the deployed server, on the launch that flushed a five-item batch:
///
/// ```
/// 03:51:04.581  GET  /me/history  200   (empty)
/// 03:51:04.697  POST /attempts    200   (five rows land)
/// ```
///
/// Perfil drew **no `HISTORIAL` section at all** while the server held a
/// complete session, and only the next relaunch showed it.
///
/// **A count and not an instant, so nothing needs a clock.** The server's
/// history changes when — and only when — a batch of attempts is recorded, so
/// a tally of recordings held against the tally at the last ask is exactly the
/// question *is there something new to read*. Two devices, two clocks and a
/// server's own `occurred_at` never have to be reconciled, and a count cannot
/// drift the way a timestamp does.
library;

/// Whether what this root last read could be behind what the server holds.
///
/// [recordedWhenAsked] is the tally as it stood when this root last sent a
/// request, and **null means it has never sent one** — which is a different
/// fact from having asked when the tally was zero, and is the state of a
/// profile whose session arrived after it was built.
///
/// **It fails toward asking.** A count read before a request is sent can be
/// overtaken by a batch that lands while that request is in flight, so an
/// equality is the only case confident enough to stay silent; anything else —
/// never asked, moved up, or moved backwards because storage was cleared —
/// costs one request and saves the section a player just earned.
bool historyOutdated({
  required int? recordedWhenAsked,
  required int recordedNow,
}) =>
    recordedWhenAsked == null || recordedNow != recordedWhenAsked;
