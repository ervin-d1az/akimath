import { readShippedPacks, type ShippedPack } from "../../src/adapters/shipped-packs.js";

/**
 * The current version of a shipped pack, by the name a test knows it under.
 *
 * `readShippedPacks()` is keyed by the **versioned** content id — a name plus a
 * digest of the artifact — because that is what `offline_packs.content_id`
 * holds and what `getOfflinePack` looks up. A test knows `starter`, not the
 * digest of whatever `npm run build:pack` last emitted, so it asks by name.
 *
 * **Here rather than on the production interface.** `POST /packs` is the one
 * caller that starts from a name, and it resolves the same way inline; adding
 * an export for the tests' convenience would put a lookup in `shipped-packs.ts`
 * that nothing in a request path needs.
 */
export function shippedPackNamed(name: string): ShippedPack {
  const found = [...readShippedPacks().values()].find((shipped) => shipped.name === name);
  if (found === undefined) {
    throw new Error(`this build ships no pack called "${name}"`);
  }
  return found;
}
