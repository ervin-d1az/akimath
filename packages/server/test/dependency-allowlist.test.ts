import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

/**
 * The runtime packages `@akimath/server` is allowed to ship.
 *
 * This list is the contract, and it mirrors `app/`'s
 * `dependency_allowlist_test.dart` deliberately: the test cannot judge whether a
 * dependency collects data, so it fails on *any* addition and summons a human
 * who can. DEP-1 names the allowlist as the audit's home, so the audit is a
 * comment on the entry rather than a line in a commit message nobody greps.
 */
const ALLOWED_RUNTIME_DEPENDENCIES: ReadonlySet<string> = new Set([
  // Added 2026-08-17 by `f1-schema-freeze`. The Postgres client. There is no
  // database without one, and `ARCHITECTURE.md` §5 picks `pg` over the Neon
  // serverless driver by name: the sync batch computes Glicko in TypeScript
  // between an INSERT's `RETURNING` and a `user_skills` upsert, which is an
  // interactive transaction the HTTP driver cannot run.
  //
  // **DEP-1 audit, performed before the addition and recorded here because the
  // rule requires it in the same change:**
  // · It opens a TCP socket to the database it is configured for, and to
  //   nothing else. No telemetry endpoint, no update check, no analytics.
  // · It has no postinstall script. Verified against the resolved package's
  //   own `package.json`, which is what the assertion below re-checks on every
  //   run, because a postinstall is how a package reaches the network at a time
  //   nobody is watching.
  // · **It never ships to a device.** The under-13 constraint that governs
  //   `app/` does not reach a server dependency — which is exactly why this is
  //   written down rather than waved through. "The rule is about the client" is
  //   how the first unaudited dependency gets in.
  // · Pinned **exactly**, not with a caret, matching `zod@4.4.3` in
  //   `packages/contract`.
  "pg",

  // Added 2026-08-19 by `f3-hono-adapter`. The HTTP framework, named by
  // `ARCHITECTURE.md` §5 ("Hono confirmed, 4.13.x"). It replaces a `node:http`
  // handler that would otherwise have to grow a JSON body parser and a
  // middleware chain by hand — and the first middleware is the session check,
  // which `CLAUDE.md` forbids hand-writing.
  //
  // **DEP-1 audit, performed before the addition:**
  // · **It declares no dependencies at all.** `npm view hono@4.13.3
  //   dependencies` prints nothing, and the installed tree adds exactly this
  //   package. That is the rarest thing on this list and the main reason it is
  //   on it.
  // · No postinstall and no install script. Re-checked on every run below.
  // · No hardcoded host anywhere in `dist/index.js` — grepped for `https://`
  //   and found none, so there is no telemetry endpoint to disable.
  // · `npm audit --omit=dev` reports **0 vulnerabilities** in the runtime tree.
  //   (The two moderate advisories `npm audit` shows are
  //   `@stryker-mutator/core` → `typed-rest-client`, which is a dev
  //   dependency and does not ship.)
  // · **It never ships to a device**, the same as `pg` — and written down for
  //   the same reason: "the rule is about the client" is how the first
  //   unaudited dependency gets in.
  // · Pinned exactly.
  "hono",

  // Added 2026-08-19 by the same change. The Node adapter for the above: Hono
  // speaks web-standard `Request`/`Response`, and this is what listens on a
  // socket and translates.
  //
  // **DEP-1 audit:**
  // · **Also declares no dependencies**, only a peer on `hono@^4` — which is
  //   the entry above, already audited, rather than a tree of its own.
  // · No postinstall, no install script, no hardcoded host.
  // · Together the two add **two packages** to the runtime tree and nothing
  //   transitive. That was the condition for adopting a framework at all.
  // · Pinned exactly.
  "@hono/node-server",

  // Added 2026-08-19 by `f3-verify-the-session`. JOSE primitives — here, only
  // `jwtVerify` and `createRemoteJWKSet`. ADR 0002 makes Neon Auth the identity
  // provider and its access token a JWT signed with EdDSA (Ed25519); verifying
  // that signature is the one thing on this list `CLAUDE.md` explicitly forbids
  // writing ourselves ("never hand-write authentication crypto").
  //
  // **DEP-1 audit, performed before the addition:**
  // · **No dependencies and no peer dependencies.** `npm view jose@6.2.9
  //   dependencies` and `peerDependencies` both print nothing.
  // · **No `scripts` key at all**, so no postinstall and nothing to run at
  //   install time. Re-checked on every run below.
  // · **No hardcoded host anywhere in the shipped JavaScript.** Grepped
  //   `dist/webapi` for `https?://` and found none; the four URLs in the
  //   tarball are all in `.d.ts` doc comments (MDN, W3C, RFC editor, GitHub).
  //   `createRemoteJWKSet` fetches **only the URL its caller passes**, and it
  //   throws unless that argument is a `URL` instance.
  // · `npm audit --omit=dev` reports **0 vulnerabilities** in the runtime tree.
  // · MIT, 248 KB unpacked, one build (`dist/webapi`) over the platform's
  //   WebCrypto rather than a native addon.
  // · **It never ships to a device.** The Dart client verifies nothing.
  // · Pinned exactly.
  "jose",
]);

/**
 * The packages in this repository that this one depends on.
 *
 * **A separate list, because DEP-1 is about a different question.** That rule
 * exists to stop third-party code that phones home, collects data or runs at
 * install time; it summons a human because a test cannot judge those. None of
 * them can be true of a package in this tree: every one is read in this
 * repository, gated by the same CI, and its own allowlist is checked by its own
 * suite. Folding them into the list above would make the pin rule ("no caret,
 * no tilde") unsatisfiable — a workspace link has no version — and the usual
 * fix for an unsatisfiable rule is to delete it.
 *
 * What they are held to instead is below: linked by path rather than fetched,
 * present on disk, and carrying no third-party runtime dependency this package
 * has not already audited.
 */
const FIRST_PARTY: ReadonlySet<string> = new Set([
  // Added 2026-08-19 by `f3-attempt-sync`. The rederivation machine: the server
  // grades an attempt by resolving the recorded `(template_id,
  // template_version, seed, ladder_step)` and regenerating the item, which is
  // the whole reason the answer never has to travel. Zero runtime dependencies
  // of its own, enforced by its own `test/dependency-allowlist.test.ts`.
  "@akimath/core",

  // Added by the same change. The canonicalizer. Grading compares canonical
  // spellings, and `packages/contract` is the one that Dart is golden-tested
  // against — a third implementation written here is exactly the drift risk R2
  // names. It brings `zod`, pinned exactly, which the assertion below checks.
  "@akimath/contract",
]);

interface Manifest {
  readonly dependencies?: Readonly<Record<string, string>>;
  readonly devDependencies?: Readonly<Record<string, string>>;
}

function readManifest(relative: string): Manifest {
  const path = fileURLToPath(new URL(relative, import.meta.url));
  return JSON.parse(readFileSync(path, "utf8")) as Manifest;
}

/** An exact pin: no caret, no tilde, no range. */
function isExactlyPinned(range: string): boolean {
  return /^\d+\.\d+\.\d+$/.test(range);
}

describe("the runtime dependency list is a committed allowlist", () => {
  const manifest = readManifest("../package.json");
  const declared = Object.keys(manifest.dependencies ?? {});

  const thirdParty = declared.filter((name) => !FIRST_PARTY.has(name));

  it("declares no third-party runtime dependency the allowlist does not", () => {
    expect(new Set(thirdParty)).toEqual(ALLOWED_RUNTIME_DEPENDENCIES);
  });

  it("and no first-party one the other list does not", () => {
    // Both directions. A package in this tree that stops being depended on
    // should leave the list, or the list stops describing anything.
    const declaredFirstParty = declared.filter((name) => FIRST_PARTY.has(name));
    expect(new Set(declaredFirstParty)).toEqual(FIRST_PARTY);
  });

  it("links a first-party package by path, never by version", () => {
    // A version range would resolve against a registry that has never heard of
    // `@akimath/core`, and the failure would be at install time in CI rather
    // than here.
    for (const name of FIRST_PARTY) {
      expect(manifest.dependencies?.[name], name).toBe(
        `file:../${name.replace("@akimath/", "")}`,
      );
    }
  });

  it("and a first-party package brings nothing this list has not audited", () => {
    // The transitive half. `@akimath/contract` depends on `zod`; if it ever
    // grows a second runtime dependency, that package ships inside this one and
    // has to be audited here — which is exactly what would otherwise be missed,
    // because the entry above says only "@akimath/contract".
    const brought = new Set<string>();
    for (const name of FIRST_PARTY) {
      const nested = readManifest(`../node_modules/${name}/package.json`);
      for (const [dependency, range] of Object.entries(nested.dependencies ?? {})) {
        if (FIRST_PARTY.has(dependency)) {
          continue;
        }
        brought.add(dependency);
        expect(
          isExactlyPinned(range),
          `${name} brings ${dependency} as "${range}"; it ships, so it is pinned exactly`,
        ).toBe(true);
      }
    }
    console.log(
      `  dependency allowlist · first-party → ${FIRST_PARTY.size} package(s) bringing ${[...brought].join(", ") || "nothing"}`,
    );
    expect([...brought].sort()).toEqual(["zod"]);
  });

  it("reports what it scanned, and scanning nothing is a failure", () => {
    // A reader one typo away from matching nothing passes forever.
    expect(declared.length).toBeGreaterThan(0);
    console.log(
      `  dependency allowlist · runtime → ${declared.length} package(s)`,
    );
  });

  it("pins every third-party runtime dependency exactly", () => {
    // First-party ones are excluded because a workspace link has no version to
    // pin — they are held to `file:../<name>` above instead, which is a
    // stronger statement: it cannot resolve to anything but this tree.
    for (const [name, range] of Object.entries(manifest.dependencies ?? {})) {
      if (FIRST_PARTY.has(name)) {
        continue;
      }
      expect(
        isExactlyPinned(range),
        `${name} is declared as "${range}"; runtime dependencies are pinned exactly`,
      ).toBe(true);
    }
  });

  it("ships nothing with a postinstall script", () => {
    // The audit above claims `pg` has none. This is that claim re-checked
    // against the resolved package on every run rather than trusted to the day
    // it was written — a postinstall is how a package reaches the network at a
    // moment nobody is watching.
    for (const name of declared) {
      const resolved = readManifest(
        `../node_modules/${name}/package.json`,
      ) as Manifest & { scripts?: Record<string, string> };
      expect(
        resolved.scripts?.postinstall,
        `${name} declares a postinstall script`,
      ).toBeUndefined();
    }
  });

  it("dev dependencies are out of scope", () => {
    // They do not ship. Sweeping them in would make the gate fire on every
    // test-tooling bump and get disabled within a week.
    expect(Object.keys(manifest.devDependencies ?? {}).length).toBeGreaterThan(
      0,
    );
    for (const name of Object.keys(manifest.devDependencies ?? {})) {
      expect(ALLOWED_RUNTIME_DEPENDENCIES.has(name)).toBe(false);
    }
  });
});
