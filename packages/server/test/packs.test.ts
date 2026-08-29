import { templateRefOf } from "@akimath/core";
import { describe, expect, it } from "vitest";

import { shippedPackNamed } from "./support/shipped.js";
import {
  contentIdFor,
  issuedCopy,
  noSuchPackResponse,
  packExpiry,
  PACK_LIFETIME_MS,
} from "../src/packs.js";

describe("a shipped pack issued as a copy of itself", () => {
  const shipped = shippedPackNamed("starter").pack;
  const issuedAt = new Date("2026-11-01T00:00:00.000Z");
  const expiresAt = new Date("2026-12-01T00:00:00.000Z");
  const copy = () => issuedCopy({ content: shipped, issuedAt, expiresAt });

  it("is the content the app already ships, item for item", () => {
    // Eighty items and thirty-five boards, against the twenty subtractions
    // `issuedPack` can generate. Until digests could grade an authored item,
    // the worse content was the only content the loop reached.
    const { pack } = copy();

    expect(pack.items).toEqual(shipped.items);
    expect(pack.puzzles).toEqual(shipped.puzzles);
    expect(pack.pack_salt).toBe(shipped.pack_salt);
    // Eighty, against the twenty a generator could make. That generator is
    // gone: after 0005 both were equally gradeable and only one was worth
    // playing, and code nothing calls is a claim about the server that is
    // not true.
    expect(pack.items.length).toBeGreaterThan(20);
  });

  it("but the window is the row's, not the build's", () => {
    // A pack built in August and issued in November is playable for a month
    // from November. Neither timestamp is digested, so replacing them changes
    // no item.
    const { pack } = copy();

    expect(pack.issued_at).toBe("2026-11-01T00:00:00.000Z");
    expect(pack.expires_at).toBe("2026-12-01T00:00:00.000Z");
    expect(pack.issued_at).not.toBe(shipped.issued_at);
  });

  it("every entry is a digest, one per item and in the same order", () => {
    // The artifact records what each item *is*, not what made it: an authored
    // item never had a template, and a generated one's seed is not written
    // into the pack it ends up in.
    const { pack, manifest } = copy();

    expect(manifest).toHaveLength(pack.items.length);
    manifest.forEach((entry, index) => {
      expect(entry.kind, `entry ${index}`).toBe("digest");
      expect(templateRefOf(entry), `entry ${index}`).toBeNull();
      expect(entry).toEqual({
        kind: "digest",
        digest: pack.items[index]!.answer.digest,
        skill_id: pack.items[index]!.skill_id,
      });
    });
  });

  it("and the boards get none, because nothing can grade one", () => {
    // A puzzle leaves no row in any table. `(packId, index)` addresses `items`,
    // so a boards entry would shift every index after it.
    const { pack, manifest } = copy();

    expect(pack.puzzles).not.toHaveLength(0);
    expect(manifest).toHaveLength(pack.items.length);
  });

  it("it refuses to issue a copy the client would refuse", () => {
    // The same `parsePack` the app runs. A pack this server would not accept
    // never leaves it — and here the window itself is the thing broken.
    expect(() =>
      issuedCopy({
        content: { ...shipped, pack_salt: "not a salt" },
        issuedAt,
        expiresAt,
      }),
    ).toThrow(/the issued copy is not a pack/);
  });

  it("and the same inputs make the same copy", () => {
    expect(JSON.stringify(copy())).toBe(JSON.stringify(copy()));
  });
});

describe("the id a row records for the content it is a copy of", () => {
  const artifact = "a".repeat(64);
  const edited = "b".repeat(64);

  it("names the content and pins the bytes it was copied from", () => {
    // A name alone is not an identity: `starter` resolves to whatever the build
    // ships today, and an outstanding row would follow it wherever it went.
    expect(contentIdFor("starter", artifact)).toBe(`starter@${artifact}`);
  });

  it("so editing the artifact under one name makes two ids", () => {
    // The whole point. Two ids means the stale one resolves to nothing, and a
    // pack this build can no longer describe is the 404 it already answers.
    expect(contentIdFor("starter", artifact)).not.toBe(contentIdFor("starter", edited));
  });

  it("and two names over identical bytes are still two ids", () => {
    // Which content a row is a copy of stays a fact about the row, so a second
    // shipped pack that happened to be byte-identical is not silently the first.
    expect(contentIdFor("starter", artifact)).not.toBe(contentIdFor("refresher", artifact));
  });
});
