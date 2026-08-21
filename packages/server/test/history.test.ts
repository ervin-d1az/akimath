import { describe, expect, it } from "vitest";

import {
  historyResponse,
  HISTORY_LIMIT,
  roundedDelta,
  sessionScore,
  sessionTitle,
  type SessionSummary,
} from "../src/history.js";
import { schemaNamed } from "./support/contract.js";

const AT = new Date("2026-08-19T09:15:00.000Z");
const session = (over: Partial<SessionSummary> = {}): SessionSummary => ({
  at: AT,
  total: 5,
  correct: 4,
  skillId: 1,
  ratingDelta: null,
  ...over,
});

describe("what a session is called", () => {
  it("the skill's name, where the skill has one", () => {
    expect(sessionTitle(1)).toBe("Restas");
  });

  it("and a generic one where it does not", () => {
    // A blank title is a row that reads as broken; a skill chosen by iteration
    // order is a lie about what was practised.
    expect(sessionTitle(7)).toBe("Serie de retos");
    expect(sessionTitle(null)).toBe("Serie de retos");
  });
});

describe("what a session scored", () => {
  it("reads the way it reads on a screen", () => {
    expect(sessionScore(4, 5)).toBe("4/5");
    expect(sessionScore(0, 1)).toBe("0/1");
    expect(sessionScore(5, 5)).toBe("5/5");
  });
});

describe("how a rating movement reads on a screen", () => {
  it("is a whole number of rating points, because the schema has no other kind", () => {
    // `HistoryEntry.ratingDelta` is `{type: integer, nullable: true}`. The
    // stored figure is the difference between two `real` columns, so somewhere
    // it has to become whole, and that somewhere is the presentation layer —
    // the record keeps every digit it was written with.
    expect(roundedDelta(12.4)).toBe(12);
    expect(roundedDelta(12.6)).toBe(13);
    expect(roundedDelta(-8.6)).toBe(-9);
  });

  it("a measured change too small to show is zero, and that is a measurement", () => {
    // This is why a session nobody measured is null rather than zero: zero is
    // already taken. A player who performed exactly as the classes predicted
    // moved by a third of a point, and `0` is the honest rendering of that.
    expect(roundedDelta(0.3)).toBe(0);
  });

  it("and a downward one too small to show is zero, not minus zero", () => {
    // `Math.round(-0.2)` is `-0`, which `Object.is` — and therefore a test's
    // `toEqual` — treats as a different value from `0`. A rating that slipped
    // by a fifth of a point is not a distinct outcome from one that held.
    expect(Object.is(roundedDelta(-0.2), 0)).toBe(true);
  });

  it("nothing measured stays nothing", () => {
    expect(roundedDelta(null)).toBeNull();
  });
});

describe("the history a player is answered with", () => {
  it("is one entry per session, in the frozen shape", () => {
    const response = historyResponse([session()]);

    expect(response.status).toBe(200);
    expect(response.body).toEqual({
      entries: [
        {
          kind: "series",
          title: "Restas",
          at: "2026-08-19T09:15:00.000Z",
          score: "4/5",
          ratingDelta: null,
        },
      ],
    });
  });

  it("carries every field the schema requires and none it does not", () => {
    const { entries } = historyResponse([session()]).body as {
      entries: Record<string, unknown>[];
    };
    const schema = schemaNamed("HistoryEntry") as {
      required: string[];
      properties: Record<string, unknown>;
    };

    expect(Object.keys(entries[0]!).sort()).toEqual([...schema.required].sort());
    expect(Object.keys(entries[0]!).sort()).toEqual(Object.keys(schema.properties).sort());
  });

  it("reports the movement a session was recorded as causing", () => {
    const { entries } = historyResponse([session({ ratingDelta: 17.4 })]).body as {
      entries: { ratingDelta: unknown }[];
    };
    expect(entries[0]!.ratingDelta).toBe(17);
  });

  it("and never claims a rating that was not recorded", () => {
    // **Two sessions reach this with nothing to report, and they are the same
    // null.** One was never measured — every answer met a class nobody had
    // met, so the answers taught the class and the player did not move. The
    // other spanned two skills, which moved two ratings by different amounts
    // in possibly opposite directions, and no single figure is a fact about
    // it. A number for either would be invented.
    const { entries } = historyResponse([
      session({ ratingDelta: null }),
      session({ correct: 0, skillId: null, ratingDelta: null }),
    ]).body as { entries: { ratingDelta: unknown }[] };
    expect(entries.every((entry) => entry.ratingDelta === null)).toBe(true);
  });

  it("and never claims a puzzle", () => {
    // The other `kind` the schema allows. A puzzle leaves no row in any table,
    // so nothing records that one was solved and nothing can report it.
    const { entries } = historyResponse([session(), session()]).body as {
      entries: { kind: string }[];
    };
    expect(new Set(entries.map((entry) => entry.kind))).toEqual(new Set(["series"]));
  });

  it("a player who has played nothing gets a list, not a 404", () => {
    // An empty history is the ordinary state of somebody who just linked. A
    // 404 would send a working client looking for a bug.
    expect(historyResponse([])).toEqual({ status: 200, body: { entries: [] } });
  });

  it("the cap is stated rather than buried in a query", () => {
    // The operation declares no parameters, so there is no page to ask for and
    // nothing a client could do with a cursor it cannot send.
    expect(HISTORY_LIMIT).toBe(50);
  });
});
