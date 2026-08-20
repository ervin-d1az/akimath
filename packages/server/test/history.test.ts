import { describe, expect, it } from "vitest";

import {
  historyResponse,
  HISTORY_LIMIT,
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

  it("never claims a rating it does not have", () => {
    // `ratingDelta` is nullable in the frozen schema, and rating is F4. A
    // number here would be invented.
    const { entries } = historyResponse([session(), session({ correct: 0 })]).body as {
      entries: { ratingDelta: unknown }[];
    };
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
