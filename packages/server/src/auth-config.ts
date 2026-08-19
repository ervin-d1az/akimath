/**
 * Where the signing keys are, and who is allowed to have signed.
 *
 * **PURE** — a function of the environment map handed to it, not of
 * `process.env`. The adapter passes the real one; the tests pass a literal, and
 * nothing here reads a file or opens a socket.
 */

/** A resolved configuration, or the reason there is not one. */
export type AuthConfig =
  | { readonly issuer: string; readonly jwksUrl: string }
  | { readonly problem: string };

const BASE = "NEON_AUTH_BASE_URL";
const JWKS = "NEON_AUTH_JWKS_URL";

/** Where plaintext is allowed, because there is no network to sniff. */
const LOOPBACK = new Set(["localhost", "127.0.0.1", "[::1]"]);

/**
 * Resolves the two facts the verifier needs from the one URL Neon gives you.
 *
 * **The issuer is the URL's origin, not the URL.** Neon's own troubleshooting
 * note is explicit: a Neon Auth URL of `https://ep-xx.aws.neon.tech/neondb/auth`
 * issues tokens whose `iss` is `https://ep-xx.aws.neon.tech`. Getting this wrong
 * rejects every valid token with an error that blames the token.
 *
 * **The JWKS URL is derived unless it was given.** Neon injects
 * `NEON_AUTH_JWKS_URL` into its own runtimes, and an authoritative value must
 * win over a derivation; everywhere else it is `/.well-known/jwks.json` under
 * the base.
 *
 * A missing or unparseable base URL is a **problem**, returned rather than
 * defaulted. A server that starts without knowing where the keys are refuses
 * every request, and an operator reads that as "authentication is broken"
 * rather than "I forgot a variable".
 */
export function readAuthConfig(env: Record<string, string | undefined>): AuthConfig {
  const base = (env[BASE] ?? "").trim();
  if (base.length === 0) {
    return { problem: `${BASE} is not set, so there is no key set to verify against.` };
  }

  let parsed: URL;
  try {
    parsed = new URL(base);
  } catch {
    return { problem: `${BASE} is "${base}", which is not a URL.` };
  }

  // A bearer token sent over plaintext is not a secret. `localhost` is exempt
  // because there is no network to sniff and it is where this is developed.
  const isLoopback = LOOPBACK.has(parsed.hostname);
  if (parsed.protocol !== "https:" && !isLoopback) {
    return {
      problem: `${BASE} is "${base}". A session travels in a header, so it needs https.`,
    };
  }

  const withoutTrailingSlash = parsed.href.replace(/\/+$/, "");
  const explicit = (env[JWKS] ?? "").trim();
  return {
    issuer: parsed.origin,
    jwksUrl: explicit.length > 0 ? explicit : `${withoutTrailingSlash}/.well-known/jwks.json`,
  };
}
