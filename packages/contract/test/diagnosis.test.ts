import { describe, expect, it } from "vitest";

import { canonicalize } from "../src/canon.js";
import { lookupDiagnosis } from "../src/diagnosis.js";
import { parsePack } from "../src/pack.js";
import { answerDigest, digestStoredAnswer } from "../src/digest.js";

const PACK_SALT = "a1b2c3d4e5f60718293a4b5c6d7e8f90";
const MINUS_SIGN = "−";

// Produced outside this package with python's hmac over the same salt and
// message, so a bug in src/digest.ts cannot define its own expectation.
const DIGEST_OF_MINUS_FIVE = "ad04dd962090a70e13f1e660757a2cc20561a8739251ce6f21241336035e6d84";
const DIGEST_OF_ONE_HALF = "de98235df9520f64dfee6e6de3d8a3a6685cbf5132990249ea29f33d867ccccd";

describe("answerDigest", () => {
  it("is HMAC-SHA-256 of the canonical answer under the pack salt", () => {
    expect(answerDigest(PACK_SALT, "-5")).toBe(DIGEST_OF_MINUS_FIVE);
  });

  it("digests a fraction the same way", () => {
    expect(answerDigest(PACK_SALT, "1/2")).toBe(DIGEST_OF_ONE_HALF);
  });

  it("emits lowercase hex, untruncated", () => {
    expect(answerDigest(PACK_SALT, "7")).toMatch(/^[0-9a-f]{64}$/u);
  });

  it("gives two spellings of one answer the same digest once canonicalized", () => {
    const typed = canonicalize(`${MINUS_SIGN}5`);
    const stored = canonicalize("-5");
    expect(typed.ok && stored.ok).toBe(true);
    if (!typed.ok || !stored.ok) {
      return;
    }
    expect(answerDigest(PACK_SALT, typed.value)).toBe(answerDigest(PACK_SALT, stored.value));
  });

  it("gives a different salt a different digest", () => {
    expect(answerDigest("00".repeat(16), "-5")).not.toBe(DIGEST_OF_MINUS_FIVE);
  });
});

describe("digestStoredAnswer", () => {
  it("digests an answer that is already canonical", () => {
    expect(digestStoredAnswer(PACK_SALT, "-5")).toEqual({
      ok: true,
      digest: DIGEST_OF_MINUS_FIVE,
    });
  });

  it("refuses to digest pack content that is not canonical", () => {
    expect(digestStoredAnswer(PACK_SALT, `${MINUS_SIGN}5`)).toEqual({
      ok: false,
      tag: "not_canonical",
    });
  });

  it("reports the canonicalizer's own tag for malformed content", () => {
    expect(digestStoredAnswer(PACK_SALT, "1/0")).toEqual({ ok: false, tag: "zero_denominator" });
  });
});

const ADDS_DENOMINATORS = {
  misconception: "adds_denominators",
  steps: ["Suma solo los de arriba.", "Los de abajo se quedan igual."],
  explain: "Cuando las partes son del mismo tamaño, se juntan las de arriba.",
};

const SKILL_FALLBACK = {
  misconception: "unclassified",
  steps: ["Vuelve a ver el paso de en medio."],
  explain: "Aquí va el razonamiento completo, paso por paso.",
};

const WRONG_ANSWER_DIGEST = answerDigest(PACK_SALT, "2/5");
const CORRECT_ANSWER_DIGEST = answerDigest(PACK_SALT, "5/6");

function packWithDiagnosis(diagnosis: unknown): Record<string, unknown> {
  return {
    pack_format_version: 1,
    pack_salt: PACK_SALT,
    issued_at: "2026-08-16T00:00:00.000Z",
    expires_at: "2026-09-15T00:00:00.000Z",
    skill_nodes: [{ skill_id: 2, state: "started" }],
    skill_fallbacks: [{ skill_id: 2, diagnosis: SKILL_FALLBACK }],
    items: [
      {
        skill_id: 2,
        ladder_step: 4,
        keypad: "item",
        stimulus: {
          kind: "arithmetic",
          payload: { operator: "+", left: { num: 1, den: 2 }, right: { num: 1, den: 3 } },
        },
        answer: { shape: "fraction", digest: CORRECT_ANSWER_DIGEST },
        diagnosis,
      },
    ],
    puzzles: [],
  };
}

const FILLED_DIAGNOSIS = {
  diagnosis_version: 1,
  distractors: [{ digest: WRONG_ANSWER_DIGEST, diagnosis: ADDS_DENOMINATORS }],
};

describe("the reserved diagnosis slot", () => {
  it("parses a pack whose item declares no diagnosis at all", () => {
    const parsed = parsePack(packWithDiagnosis(null));
    expect(parsed.ok).toBe(true);
    if (!parsed.ok) {
      return;
    }
    expect(parsed.pack.items[0]?.diagnosis).toBeNull();
  });

  it("parses a pack whose item carries a filled, separately versioned diagnosis", () => {
    const parsed = parsePack(packWithDiagnosis(FILLED_DIAGNOSIS));
    expect(parsed.ok).toBe(true);
    if (!parsed.ok) {
      return;
    }
    expect(parsed.pack.items[0]?.diagnosis?.diagnosis_version).toBe(1);
  });

  it("finds a labelled distractor by the digest of its canonical answer", () => {
    const parsed = parsePack(packWithDiagnosis(FILLED_DIAGNOSIS));
    expect(parsed.ok).toBe(true);
    if (!parsed.ok) {
      return;
    }
    const [item] = parsed.pack.items;
    expect(item).toBeDefined();
    if (item === undefined) {
      return;
    }
    const typed = digestStoredAnswer(PACK_SALT, "2/5");
    expect(typed.ok).toBe(true);
    if (!typed.ok) {
      return;
    }
    expect(lookupDiagnosis(item, parsed.pack.skill_fallbacks, typed.digest)).toEqual(
      ADDS_DENOMINATORS,
    );
  });

  it("rejects a distractor carrying its answer in plaintext beside the digest", () => {
    expect(
      parsePack(
        packWithDiagnosis({
          diagnosis_version: 1,
          distractors: [
            { digest: WRONG_ANSWER_DIGEST, diagnosis: ADDS_DENOMINATORS, answer: "2/5" },
          ],
        }),
      ),
    ).toEqual({ ok: false, tag: "schema_violation" });
  });

  it("rejects a diagnosis claiming a version this package does not speak", () => {
    expect(parsePack(packWithDiagnosis({ ...FILLED_DIAGNOSIS, diagnosis_version: 2 }))).toEqual({
      ok: false,
      tag: "schema_violation",
    });
  });

  it("rejects two distractors keyed by the same digest", () => {
    expect(
      parsePack(
        packWithDiagnosis({
          diagnosis_version: 1,
          distractors: [
            { digest: WRONG_ANSWER_DIGEST, diagnosis: ADDS_DENOMINATORS },
            { digest: WRONG_ANSWER_DIGEST, diagnosis: SKILL_FALLBACK },
          ],
        }),
      ),
    ).toEqual({ ok: false, tag: "duplicate_distractor_digest" });
  });

  it("rejects a distractor digest that is the item's own answer", () => {
    expect(
      parsePack(
        packWithDiagnosis({
          diagnosis_version: 1,
          distractors: [{ digest: CORRECT_ANSWER_DIGEST, diagnosis: ADDS_DENOMINATORS }],
        }),
      ),
    ).toEqual({ ok: false, tag: "distractor_matches_answer" });
  });
});

describe("the generic per-skill fallback", () => {
  it("resolves an answer no distractor anticipated to the skill's fallback", () => {
    const parsed = parsePack(packWithDiagnosis(FILLED_DIAGNOSIS));
    expect(parsed.ok).toBe(true);
    if (!parsed.ok) {
      return;
    }
    const [item] = parsed.pack.items;
    if (item === undefined) {
      return;
    }
    const unanticipated = digestStoredAnswer(PACK_SALT, "9/4");
    expect(unanticipated.ok).toBe(true);
    if (!unanticipated.ok) {
      return;
    }
    expect(lookupDiagnosis(item, parsed.pack.skill_fallbacks, unanticipated.digest)).toEqual(
      SKILL_FALLBACK,
    );
  });

  it("resolves to the fallback even when the item carries no diagnosis at all", () => {
    const parsed = parsePack(packWithDiagnosis(null));
    expect(parsed.ok).toBe(true);
    if (!parsed.ok) {
      return;
    }
    const [item] = parsed.pack.items;
    if (item === undefined) {
      return;
    }
    expect(lookupDiagnosis(item, parsed.pack.skill_fallbacks, WRONG_ANSWER_DIGEST)).toEqual(
      SKILL_FALLBACK,
    );
  });

  it("rejects a pack carrying an item for a skill that declares no fallback", () => {
    expect(
      parsePack({ ...packWithDiagnosis(null), skill_fallbacks: [] }),
    ).toEqual({ ok: false, tag: "missing_skill_fallback" });
  });

  it("rejects a pack whose fallback belongs to a different skill", () => {
    expect(
      parsePack({
        ...packWithDiagnosis(null),
        skill_nodes: [
          { skill_id: 2, state: "started" },
          { skill_id: 7, state: "locked" },
        ],
        skill_fallbacks: [{ skill_id: 7, diagnosis: SKILL_FALLBACK }],
      }),
    ).toEqual({ ok: false, tag: "missing_skill_fallback" });
  });
});
