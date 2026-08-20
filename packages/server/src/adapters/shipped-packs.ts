import { readFileSync } from "node:fs";
import { createRequire } from "node:module";

import { parsePack, type Pack } from "@akimath/contract";

/**
 * The packs this build can issue, read once.
 *
 * **ADAPTER.** It touches the filesystem exactly once, at startup, and hands
 * back values. A request path that read a file would be ambient IO in the one
 * place this package forbids it — and it would also mean a pack's content
 * could change under a player mid-session.
 *
 * **Resolved through `@akimath/core`'s `exports`**, not by walking up
 * directories. The package publishes `./pack/starter.json`; reaching past that
 * into another package's tree is the kind of coupling that survives exactly
 * until somebody moves a folder.
 *
 * **Validated on the way in.** `parsePack` is the same check the client runs,
 * so a build shipping a pack the app would refuse fails at startup rather than
 * at the first player who asks for one.
 */
export interface ShippedPack {
  /** What `offline_packs.content_id` records. Short, stable, and content's. */
  readonly id: string;
  readonly pack: Pack;
}

/** The one pack this build ships. A list, because there will be more. */
const SHIPPED: readonly { readonly id: string; readonly specifier: string }[] = [
  { id: "starter", specifier: "@akimath/core/pack/starter.json" },
];

export function readShippedPacks(): ReadonlyMap<string, ShippedPack> {
  const resolve = createRequire(import.meta.url).resolve;
  const packs = new Map<string, ShippedPack>();

  for (const { id, specifier } of SHIPPED) {
    const parsed = parsePack(JSON.parse(readFileSync(resolve(specifier), "utf8")));
    if (!parsed.ok) {
      // Thrown at startup, deliberately. A pack the client would refuse is a
      // build that should not serve, and finding out at the first request
      // means finding out in front of a player.
      throw new Error(`the shipped pack "${id}" is not a pack: ${parsed.tag}`);
    }
    packs.set(id, { id, pack: parsed.pack });
  }
  return packs;
}

/**
 * The shipped packs, read on first use and shared after.
 *
 * **Lazily, not at module load.** A module that reads a file at import turns a
 * bad artifact into an *import* failure, and an import failure is not a test
 * failure: every file importing it dies before its assertions run. That cost
 * `packages/core` thirty-seven mutants once (PROC-5 step 0b), and it would cost
 * this one a startup crash with no line number.
 */
let cached: ReadonlyMap<string, ShippedPack> | undefined;

export function shippedPacks(): ReadonlyMap<string, ShippedPack> {
  cached ??= readShippedPacks();
  return cached;
}
