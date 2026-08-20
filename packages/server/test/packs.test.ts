import { answerDigest, canonicalize, parsePack, storedAnswer } from "@akimath/contract";
import { coreRegistry, fromManifestEntry, rederive, registryOf } from "@akimath/core";
import { describe, expect, it } from "vitest";

import {
  issuedPack,
  packExpiry,
  PACK_ITEM_COUNT,
  PACK_LADDER_STEP,
  PACK_LIFETIME_MS,
} from "../src/packs.js";

const SALT = "a1b2c3d4e5f60718293a4b5c6d7e8f90";
const ISSUED_AT = new Date("2026-08-19T09:15:00.000Z");
const seeds = (n: number): bigint[] => Array.from({ length: n }, (_u, i) => BigInt(1000 + i));

const issue = (n = PACK_ITEM_COUNT) =>
  issuedPack({ saltHex: SALT, seeds: seeds(n), issuedAt: ISSUED_AT });

describe("an issued pack is one the client would accept", () => {
  it("validates against the frozen format", () => {
    const { pack } = issue();

    const checked = parsePack(pack);
    expect(checked.ok, checked.ok ? "" : checked.tag).toBe(true);
    expect(pack.items).toHaveLength(PACK_ITEM_COUNT);
  });

  it("carries a fallback for every skill its items belong to", () => {
    // `missing_skill_fallback` is a frozen rejection tag: without this the
    // whole pack is invalid, so it is not decoration.
    const { pack } = issue();

    for (const item of pack.items) {
      expect(
        pack.skill_fallbacks.some((f) => f.skill_id === item.skill_id),
        `skill ${item.skill_id}`,
      ).toBe(true);
      expect(pack.skill_nodes.some((n) => n.skill_id === item.skill_id)).toBe(true);
    }
    expect(pack.skill_fallbacks[0]?.diagnosis.steps.length).toBeGreaterThan(0);
  });

  it("carries no puzzles, and says so with an empty list", () => {
    // A puzzle is authored and carries no template reference, so an attempt
    // against one could not be graded. Absent by rule rather than by omission.
    expect(issue().pack.puzzles).toEqual([]);
  });

  it("and the window is a month from when it was issued", () => {
    const { pack } = issue();

    expect(pack.issued_at).toBe("2026-08-19T09:15:00.000Z");
    // The date spelled out, not `issuedAt + PACK_LIFETIME_MS` — an assertion
    // built from the constant it is checking passes for any value of it, which
    // is how `30 * 24 / 60 * 60 * 1000` survived a mutation run.
    expect(pack.expires_at).toBe("2026-09-18T09:15:00.000Z");
    expect(PACK_LIFETIME_MS).toBe(2_592_000_000);
    expect(packExpiry(ISSUED_AT).toISOString()).toBe(pack.expires_at);
  });
});

describe("every item in it can be graded later, which is the whole point", () => {
  it("each manifest entry rederives to the item beside it", () => {
    // **The seam between issuing and `POST /attempts`.** An attempt names
    // `(packId, index)`; the server reads `template_refs[index]`, rederives,
    // and compares. If the two lists ever fall out of step, every pack attempt
    // grades against the wrong item and nothing says so.
    const { pack, manifest } = issue();

    expect(manifest).toHaveLength(pack.items.length);
    manifest.forEach((entry, index) => {
      const ref = fromManifestEntry(entry);
      expect(ref, `entry ${index}`).not.toBeNull();

      const generated = rederive(coreRegistry(), ref!);
      const { shape, canonical } = storedAnswer(
        generated.answer.numerator,
        generated.answer.denominator,
      );
      const item = pack.items[index]!;
      expect(item.answer.digest, `item ${index}`).toBe(answerDigest(SALT, canonical));
      expect(item.answer.shape, `item ${index}`).toBe(shape);
      expect(item.ladder_step).toBe(PACK_LADDER_STEP);
    });
  });

  it("and the digest is reachable from what a keypad produces", () => {
    // The other half of #50: a digest taken over a spelling no learner can type
    // is a pack of items that are always wrong.
    const { pack, manifest } = issue(4);

    manifest.forEach((entry, index) => {
      const generated = rederive(coreRegistry(), fromManifestEntry(entry)!);
      const typed = storedAnswer(
        generated.answer.numerator,
        generated.answer.denominator,
      ).canonical;
      const asTyped = canonicalize(typed);
      expect(asTyped.ok).toBe(true);
      expect(pack.items[index]!.answer.digest).toBe(
        answerDigest(SALT, asTyped.ok ? asTyped.value : ""),
      );
    });
  });

  it("a different salt is a different pack", () => {
    // Per-pack salt, so two players' digests are not comparable and one
    // player's pack tells nothing about another's.
    const mine = issue(2);
    const theirs = issuedPack({
      saltHex: "ffffffffffffffffffffffffffffffff",
      seeds: seeds(2),
      issuedAt: ISSUED_AT,
    });

    expect(theirs.manifest).toEqual(mine.manifest);
    expect(theirs.pack.items[0]?.answer.digest).not.toBe(mine.pack.items[0]?.answer.digest);
  });

  it("a different seed is a different item", () => {
    const first = issuedPack({ saltHex: SALT, seeds: [1n], issuedAt: ISSUED_AT });
    const second = issuedPack({ saltHex: SALT, seeds: [2n], issuedAt: ISSUED_AT });

    expect(second.pack.items[0]).not.toEqual(first.pack.items[0]);
  });

  it("the same inputs make the same pack, byte for byte", () => {
    // Deterministic, so a re-issue of a recorded pack is the pack that was
    // recorded — which is what would let `GET /packs/{packId}` rebuild rather
    // than store the body.
    expect(JSON.stringify(issue(5))).toBe(JSON.stringify(issue(5)));
  });
});

describe("and it refuses to issue one it would not accept", () => {
  it("with nothing to draw from, it says so rather than answering an empty pack", () => {
    // Unreachable while any version is issuable — and a server with no content
    // is not something a client can do anything about, so it throws rather than
    // answering. Exercised here because an unreachable branch nobody has run is
    // an unreachable branch nobody has *read*, either.
    expect(() =>
      issuedPack({ saltHex: SALT, seeds: seeds(1), issuedAt: ISSUED_AT, registry: registryOf([]) }),
    ).toThrow(/nothing to put in a pack/);
  });

  it("and a pack the frozen validator would reject never leaves", () => {
    // A ladder step outside 1–20 is a pack the client refuses. Catching it here
    // means the failure is a 500 on the server rather than an unreadable pack
    // on a phone that is now offline.
    const outOfRange = registryOf([
      {
        id: "spike.bad-step",
        version: 1,
        skillId: 1,
        generate: () => ({
          prompt: [],
          answer: { numerator: 1n, denominator: 1n },
          ladderStep: 99,
          operator: "-" as const,
          left: { num: 2, den: 1 },
          right: { num: 1, den: 1 },
        }),
      },
    ]);

    expect(() =>
      issuedPack({ saltHex: SALT, seeds: seeds(1), issuedAt: ISSUED_AT, registry: outOfRange }),
    ).toThrow(/the issued pack is not one/);
  });
});

describe("what an issued pack deliberately does not have", () => {
  it("no predicted distractors, so a wrong answer meets the fallback", () => {
    // The pack builder predicts two for subtraction. Doing it here would be a
    // second copy of `distractors.ts` across a package boundary, and the
    // diagnosis a player sees would depend on which path issued their pack.
    for (const item of issue(3).pack.items) {
      expect(item.diagnosis).toBeNull();
    }
  });

  it("and no answer in plain sight anywhere in it", () => {
    // The invariant the digest exists for. Sweeping the serialised pack is
    // cruder than reading the type and catches the case the type cannot: a
    // field added later that happens to carry one.
    const { pack, manifest } = issue(6);
    const serialised = JSON.stringify(pack);

    for (const entry of manifest) {
      const generated = rederive(coreRegistry(), fromManifestEntry(entry)!);
      const answer = storedAnswer(
        generated.answer.numerator,
        generated.answer.denominator,
      ).canonical;
      // The answer may coincide with an operand — `7 - 0` — so this looks for
      // it as a *value*, not as a substring of the whole document.
      expect(serialised).not.toContain(`"answer":"${answer}"`);
      expect(serialised).not.toContain(`"canonical":"${answer}"`);
    }
  });
});
