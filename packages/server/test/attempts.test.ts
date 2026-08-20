import { describe, expect, it } from "vitest";

import {
  ATTEMPT_ELAPSED_MS_MAX,
  ATTEMPTS_PER_BATCH_MAX,
  gradeAnswer,
  readAttemptBatch,
  unknownSourceResponse,
  verdictsResponse,
  type Attempt,
} from "../src/attempts.js";
import { registryOf } from "@akimath/core";

import { schemaNamed } from "./support/contract.js";

const ITEM = "018f4e3c-0000-7000-8000-0000000000e1";
const PACK = "018f4e3c-0000-7000-8000-0000000000e2";
const SESSION = "018f4e3c-0000-7000-8000-0000000000e3";

const submission = (over: Record<string, unknown> = {}): Record<string, unknown> => ({
  itemId: ITEM,
  sessionId: SESSION,
  answer: "-9",
  clientTs: "2026-08-19T09:15:00.000Z",
  elapsedMs: 4200,
  ...over,
});

const batch = (...attempts: unknown[]): unknown => ({ attempts });

const refusal = (body: unknown): { status: number; error: string; message: string } => {
  const read = readAttemptBatch(body);
  if (Array.isArray(read)) {
    throw new Error(`expected a refusal, got ${read.length} attempt(s)`);
  }
  const response = read as { status: number; body: { error: string; message: string } };
  return { status: response.status, error: response.body.error, message: response.body.message };
};

describe("the ceiling is the contract's, not a second opinion", () => {
  it("matches the emitted maximum exactly", () => {
    // R2 in miniature: `packages/contract` owns the figure and this package
    // restates it, because the server validates by hand rather than with Zod.
    // Two derivations, one gate — the same shape as `contract-parity.test.ts`.
    const submissionSchema = schemaNamed("AttemptSubmission") as {
      properties: Record<string, Record<string, unknown>>;
    };
    const elapsed = submissionSchema.properties["elapsedMs"]!;

    expect(elapsed["maximum"]).toBe(ATTEMPT_ELAPSED_MS_MAX);
    expect(elapsed["minimum"]).toBe(0);
  });
});

describe("a batch is read", () => {
  it("one attempt against an issued item", () => {
    const read = readAttemptBatch(batch(submission()));

    expect(read).toEqual<readonly Attempt[]>([
      {
        source: { kind: "issued", itemId: ITEM },
        sessionId: SESSION,
        answer: "-9",
        clientTs: "2026-08-19T09:15:00.000Z",
        elapsedMs: 4200,
      },
    ]);
  });

  it("and one against a pack item, whose identity is a pair", () => {
    const read = readAttemptBatch(
      batch(submission({ itemId: undefined, packRef: { packId: PACK, index: 3 } })),
    );

    expect(Array.isArray(read) && read[0]?.source).toEqual({
      kind: "pack",
      packId: PACK,
      index: 3,
    });
  });

  it("an empty batch is a batch, not a mistake", () => {
    // A client syncing "whatever I have" should not need a special case for
    // having nothing. It costs one round trip and no rows.
    expect(readAttemptBatch(batch())).toEqual([]);
  });

  it("the bounds are inclusive at both ends", () => {
    // Named separately from the refusals below, because an off-by-one here
    // refuses a legitimate attempt rather than accepting a bad one.
    expect(readAttemptBatch(batch(submission({ elapsedMs: 0 })))).toHaveLength(1);
    expect(readAttemptBatch(batch(submission({ elapsedMs: ATTEMPT_ELAPSED_MS_MAX })))).toHaveLength(1);
    expect(readAttemptBatch(batch(submission({ itemId: undefined, packRef: { packId: PACK, index: 0 } })))).toHaveLength(1);
    const atTheLimit = Array.from({ length: ATTEMPTS_PER_BATCH_MAX }, () => submission());
    expect(readAttemptBatch({ attempts: atTheLimit })).toHaveLength(ATTEMPTS_PER_BATCH_MAX);
  });

  it("a timestamp the frozen pattern allows, in each of its shapes", () => {
    for (const good of [
      "2026-01-02T03:04Z", // seconds are optional
      "2026-01-02T03:04:05Z", // and so is the fraction
      "2026-01-02T03:04:05.678Z",
      "2028-02-29T00:00:00.000Z", // a real leap day, so the rule is not "refuse every 29 February"
    ]) {
      expect(readAttemptBatch(batch(submission({ clientTs: good }))), good).toHaveLength(1);
    }
  });
});

describe("or refused, with the reason and the index", () => {
  /**
   * Every refusal, by the exact sentence it earns.
   *
   * **The message is the assertion, not the status.** Every one of these is a
   * 400; a table that checked only that would pass with all thirty messages
   * blanked, which is what a first pass of this file actually did — Stryker
   * emptied them one at a time and nothing went red.
   */
  const CASES: readonly (readonly [string, unknown, string])[] = [
    ["a body that is not an object", null, "The body must be a JSON object."],
    ["a body that is an array", [], "The body must be a JSON object."],
    // Not folded in with the two above: without the `typeof` clause a string
    // body reaches `Object.keys("hi")`, which is `["0", "1"]`, and the caller
    // is told the body "carries 0, 1".
    ["a body that is a string", "hi", "The body must be a JSON object."],
    ["a body with no attempts", {}, "The body must carry an attempts array."],
    ["attempts that is not an array", { attempts: {} }, "The body must carry an attempts array."],
    [
      "a body carrying anything else, listed",
      { attempts: [], sessionId: SESSION, ok: true },
      "The body carries sessionId, ok, which this operation does not accept.",
    ],
    [
      "more attempts than a batch may carry",
      { attempts: Array.from({ length: ATTEMPTS_PER_BATCH_MAX + 1 }, () => submission()) },
      `A batch carries at most ${ATTEMPTS_PER_BATCH_MAX} attempts; this one carries ${ATTEMPTS_PER_BATCH_MAX + 1}.`,
    ],
    ["an attempt that is null", batch(null), "attempts[0] must be a JSON object."],
    ["an attempt that is an array", batch([]), "attempts[0] must be a JSON object."],
    ["an attempt that is a string", batch("hi"), "attempts[0] must be a JSON object."],
    [
      "an attempt asserting its own verdict",
      batch(submission({ ok: true })),
      "attempts[0] carries ok, which this operation does not accept.",
    ],
    [
      "an attempt carrying two things it should not",
      batch(submission({ ok: true, score: 1 })),
      "attempts[0] carries ok, score, which this operation does not accept.",
    ],
    [
      "an attempt naming neither source",
      batch(submission({ itemId: undefined })),
      "attempts[0] must name exactly one source: itemId for an item this server issued, or packRef for one from an offline pack.",
    ],
    [
      "an attempt naming both",
      batch(submission({ packRef: { packId: PACK, index: 0 } })),
      "attempts[0] must name exactly one source: itemId for an item this server issued, or packRef for one from an offline pack.",
    ],
    ["an itemId that is not a uuid", batch(submission({ itemId: "nope" })), "attempts[0].itemId must be a uuid."],
    [
      "an itemId with something in front of it",
      // The `^` and `$` are load-bearing. Without them a uuid *inside* a longer
      // string passes, and the query then finds nothing — a 404 for what looks
      // like a well-formed id.
      batch(submission({ itemId: `urn:uuid:${ITEM}` })),
      "attempts[0].itemId must be a uuid.",
    ],
    [
      "an itemId with something after it",
      batch(submission({ itemId: `${ITEM} ` })),
      "attempts[0].itemId must be a uuid.",
    ],
    [
      "an itemId inside an array, which RegExp.test would coerce",
      // `UUID.test([itemId])` is `true`: `test` stringifies its argument. The
      // `typeof` guard in front of every pattern is what stops that.
      batch(submission({ itemId: [ITEM] })),
      "attempts[0].itemId must be a uuid.",
    ],
    [
      "a packRef that is null",
      batch(submission({ itemId: undefined, packRef: null })),
      "attempts[0].packRef must be an object with packId and index.",
    ],
    [
      "a packRef that is an array",
      batch(submission({ itemId: undefined, packRef: [PACK, 0] })),
      "attempts[0].packRef must be an object with packId and index.",
    ],
    [
      "a packRef that is a number",
      batch(submission({ itemId: undefined, packRef: 3 })),
      "attempts[0].packRef must be an object with packId and index.",
    ],
    [
      "an instant inside an array, which RegExp.exec would coerce",
      // `INSTANT.exec(["2026-01-02T03:04Z"])` matches: `exec` stringifies its
      // argument, and `String(["x"])` is `"x"`. Without a `typeof` guard the
      // array would be believed and then stored as `clientTs`. The same trap as
      // the uuids above, one method along.
      batch(submission({ clientTs: ["2026-01-02T03:04Z"] })),
      "attempts[0].clientTs must be an instant like 2026-08-19T09:15:00.000Z.",
    ],
    [
      "a packRef carrying two things it should not",
      batch(submission({ itemId: undefined, packRef: { packId: PACK, index: 0, ok: true, score: 1 } })),
      "attempts[0].packRef carries ok, score, which it does not accept.",
    ],
    [
      "a packRef carrying anything else",
      batch(submission({ itemId: undefined, packRef: { packId: PACK, index: 0, ok: true } })),
      "attempts[0].packRef carries ok, which it does not accept.",
    ],
    [
      "a packId that is not a uuid",
      batch(submission({ itemId: undefined, packRef: { packId: "x", index: 0 } })),
      "attempts[0].packRef.packId must be a uuid.",
    ],
    [
      "a packId inside an array",
      batch(submission({ itemId: undefined, packRef: { packId: [PACK], index: 0 } })),
      "attempts[0].packRef.packId must be a uuid.",
    ],
    [
      "a negative index",
      batch(submission({ itemId: undefined, packRef: { packId: PACK, index: -1 } })),
      "attempts[0].packRef.index must be a whole number, zero or more.",
    ],
    [
      "a fractional index",
      batch(submission({ itemId: undefined, packRef: { packId: PACK, index: 1.5 } })),
      "attempts[0].packRef.index must be a whole number, zero or more.",
    ],
    [
      "an index that is a string",
      batch(submission({ itemId: undefined, packRef: { packId: PACK, index: "1" } })),
      "attempts[0].packRef.index must be a whole number, zero or more.",
    ],
    ["a sessionId that is not a uuid", batch(submission({ sessionId: "nope" })), "attempts[0].sessionId must be a uuid."],
    ["a sessionId that is a number", batch(submission({ sessionId: 42 })), "attempts[0].sessionId must be a uuid."],
    [
      "a sessionId inside an array",
      batch(submission({ sessionId: [SESSION] })),
      "attempts[0].sessionId must be a uuid.",
    ],
    [
      "an answer that is not a string",
      // A number would grade against `String(9)` — right for whole answers and
      // wrong for `1/2`, which is the worst kind of nearly-working.
      batch(submission({ answer: 9 })),
      "attempts[0].answer must be a string, exactly as it was typed.",
    ],
    [
      "elapsedMs below zero",
      batch(submission({ elapsedMs: -1 })),
      `attempts[0].elapsedMs must be a whole number of milliseconds between 0 and ${ATTEMPT_ELAPSED_MS_MAX}.`,
    ],
    [
      "elapsedMs past the ceiling",
      batch(submission({ elapsedMs: ATTEMPT_ELAPSED_MS_MAX + 1 })),
      `attempts[0].elapsedMs must be a whole number of milliseconds between 0 and ${ATTEMPT_ELAPSED_MS_MAX}.`,
    ],
    [
      "a fractional elapsedMs",
      batch(submission({ elapsedMs: 1.5 })),
      `attempts[0].elapsedMs must be a whole number of milliseconds between 0 and ${ATTEMPT_ELAPSED_MS_MAX}.`,
    ],
    [
      "an elapsedMs that is a string",
      batch(submission({ elapsedMs: "4200" })),
      `attempts[0].elapsedMs must be a whole number of milliseconds between 0 and ${ATTEMPT_ELAPSED_MS_MAX}.`,
    ],
    [
      "the second attempt, named by its index",
      // A batch of fifty with one bad row is undiagnosable from "the body was
      // malformed", and the client cannot bisect a request it has already sent.
      batch(submission(), submission({ answer: 9 })),
      "attempts[1].answer must be a string, exactly as it was typed.",
    ],
  ];

  it.each(CASES)("refuses %s", (_label, body, message) => {
    expect(refusal(body)).toEqual({ status: 400, error: "malformed", message });
  });

  it("refuses every timestamp the frozen pattern refuses", () => {
    for (const wrong of [
      "2026-01-02T03:04:05.678+00:00", // an offset, not Z
      "2026-01-02T03:04:05.678", // no zone at all
      "2026-01-02 03:04:05.678Z", // a space instead of T
      "2026-02-30T00:00:00.000Z", // a day February never has
      "2025-02-29T00:00:00.000Z", // not a leap year
      "2026-13-01T00:00:00.000Z", // no such month
      "2026-01-32T00:00:00.000Z",
      "not an instant",
      // The anchors again: an instant embedded in a longer string is not one.
      " 2026-01-02T03:04:05.678Z",
      "2026-01-02T03:04:05.678Z and then some",
    ]) {
      expect(refusal(batch(submission({ clientTs: wrong }))), wrong).toEqual({
        status: 400,
        error: "malformed",
        message: "attempts[0].clientTs must be an instant like 2026-08-19T09:15:00.000Z.",
      });
    }
    // And one that is not a string at all, which `INSTANT.exec` would coerce.
    expect(refusal(batch(submission({ clientTs: 0 }))).status).toBe(400);
  });

  it("reports how many refusals it checked", () => {
    // PROC-10. A table that emptied would make `it.each` register no tests at
    // all and the file would still be green.
    expect(CASES.length).toBeGreaterThan(20);
    console.log(`  attempt refusals · ${CASES.length} case(s), each by its exact sentence`);
  });
});

describe("grading rederives and compares canonical spellings", () => {
  const ref = {
    templateId: "arith.integer.subtract",
    templateVersion: 2,
    seed: 1000n,
    ladderStep: 3,
  };

  it("marks the exact answer correct", () => {
    // −9 is what `(arith.integer.subtract@2, seed 1000, step 3)` derives to;
    // `packages/core`'s golden pins that, so this test is about the comparison
    // rather than about the arithmetic.
    expect(gradeAnswer(ref, "-9")).toBe(true);
  });

  it("and a whole answer is spelled whole, not as a fraction over one", () => {
    // The defect fixed in `packages/core` #50, restated here because the server
    // is the second place that has to spell an answer: `-9/1` is not what a
    // keypad produces and must not be what grading expects.
    expect(gradeAnswer(ref, "-9/1")).toBe(false);
  });

  it("marks anything else wrong", () => {
    expect(gradeAnswer(ref, "9")).toBe(false);
    expect(gradeAnswer(ref, "-8")).toBe(false);
  });

  it("an answer the canonicalizer refuses is wrong, not an error", () => {
    // A learner can type nonsense, and nonsense is a wrong answer. Throwing
    // here would turn one bad row into a 500 for the whole batch.
    for (const nonsense of ["", "abc", "1/0", "٩"]) {
      expect(gradeAnswer(ref, nonsense), nonsense).toBe(false);
    }
  });

  it("a fractional answer is spelled as a fraction, and a whole one is not", () => {
    // The shipped template only makes whole answers, so the other branch of the
    // spelling is unreachable through it — and "always spell it whole" passes
    // every test above. A registry of one synthetic template is what exercises
    // it, the same shape `packages/core`'s own build test uses.
    const fractional = registryOf([
      {
        id: "spike.fraction",
        version: 1,
        skillId: 1,
        generate: () => ({
          prompt: [],
          answer: { numerator: 5n, denominator: 4n },
          ladderStep: 1,
          operator: "+" as const,
          left: { num: 1, den: 2 },
          right: { num: 3, den: 4 },
        }),
      },
    ]);
    const fractionRef = {
      templateId: "spike.fraction",
      templateVersion: 1,
      seed: 0n,
      ladderStep: 1,
    };

    expect(gradeAnswer(fractionRef, "5/4", fractional)).toBe(true);
    expect(gradeAnswer(fractionRef, "5", fractional)).toBe(false);
    expect(gradeAnswer(fractionRef, "1.25", fractional)).toBe(false);
  });

  it("refuses to guess at a reference it cannot resolve", () => {
    // A version that is not in the registry is not a wrong answer, it is a
    // server that cannot do its job — and `resolve` says so rather than
    // falling back to the latest, which would rewrite history.
    expect(() => gradeAnswer({ ...ref, templateVersion: 99 }, "-9")).toThrow(/no template/);
  });
});

describe("an attempt naming something the player does not have", () => {
  it("is a 404 that names the index and says nothing landed", () => {
    // A batch is one transaction and one answer. A client told "404" with no
    // index cannot tell which row was wrong, and one told nothing about the
    // rest would not know whether to resend.
    expect(unknownSourceResponse(3)).toEqual({
      status: 404,
      body: {
        error: "no_such_item",
        message:
          "attempts[3] names an item this player does not have. Nothing in the batch was recorded.",
      },
    });
  });
});

describe("the answer a graded batch earns", () => {
  it("is one verdict per attempt, echoing the source it graded", () => {
    const response = verdictsResponse([
      { source: { kind: "issued", itemId: ITEM }, ok: true },
      { source: { kind: "pack", packId: PACK, index: 3 }, ok: false },
    ]);

    expect(response.status).toBe(200);
    expect(response.body).toEqual({
      verdicts: [
        { itemId: ITEM, ok: true, payload: {} },
        { packRef: { packId: PACK, index: 3 }, ok: false, payload: {} },
      ],
    });
  });

  it("and an empty batch earns an empty list rather than nothing", () => {
    expect(verdictsResponse([])).toEqual({ status: 200, body: { verdicts: [] } });
  });
});
