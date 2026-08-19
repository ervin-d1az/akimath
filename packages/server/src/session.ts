/**
 * What a caller offered in the `Authorization` header.
 *
 * Three cases and not two. **Absent and malformed are different answers**:
 * absent is a client that has not linked yet and needs to be told a session is
 * required; malformed is a client holding something it believes is a session,
 * which needs to be told it is not. Collapsing them leaves the second
 * undiagnosable.
 */
export type Credential =
  | { readonly kind: "absent" }
  | { readonly kind: "malformed"; readonly why: string }
  | { readonly kind: "bearer"; readonly token: string };

/** A caller whose credential verified. `userId` is the token's `sub`. */
export interface Session {
  readonly userId: string;
}

const BEARER = "bearer";

/**
 * Reads the `Authorization` header, and decides nothing else.
 *
 * No key, no clock, no network — whether the token is *good* is the verifier's
 * question, and keeping the two apart is what lets this half be exhaustive
 * without a single mock.
 *
 * The scheme is matched case-insensitively because RFC 7235 defines it that
 * way, and a client sending `bearer` is not broken.
 *
 * **A token containing a space is refused rather than truncated.** `Bearer a b`
 * could be read as the token `a` with something after it; a JWT has no spaces,
 * so reading it that way turns a client bug into an authentication failure
 * nobody can explain.
 *
 * There is no "scheme present, token empty" branch, and there was one until
 * mutation testing reported it as uncovered by any test — because it is
 * unreachable. The header is trimmed before anything else, so it never ends in
 * whitespace, so whatever follows the first space contains a non-space. `Bearer `
 * arrives here as `Bearer`, with no space in it at all, and is refused two
 * checks above as a header that names no credential.
 */
export function readCredential(header: string | undefined): Credential {
  const trimmed = (header ?? "").trim();
  if (trimmed.length === 0) {
    return { kind: "absent" };
  }

  const separator = trimmed.indexOf(" ");
  if (separator === -1) {
    return {
      kind: "malformed",
      why: `The Authorization header is "${trimmed}", which names no credential.`,
    };
  }

  const scheme = trimmed.slice(0, separator);
  if (scheme.toLowerCase() !== BEARER) {
    return {
      kind: "malformed",
      why: `This API accepts one scheme, Bearer, and the header offered ${scheme}.`,
    };
  }

  const token = trimmed.slice(separator + 1).trim();
  if (token.includes(" ")) {
    return {
      kind: "malformed",
      why: "The Bearer token contains a space, and a JWT never does.",
    };
  }

  return { kind: "bearer", token };
}

/**
 * Whether a token's subject could name an account here.
 *
 * **A uuid, because that is what the provider stores.** `neon_auth.user.id` is
 * a `uuid` — read from the catalogue rather than assumed — and so is
 * `players.auth_user_id`. A subject of any other shape cannot match a row: it
 * would reach the database as `invalid input syntax for type uuid`, which is a
 * 500 for a request that deserves a 401.
 *
 * Checked here rather than in the repository so the refusal happens before any
 * connection is borrowed, and so it is a pure rule with a pure test.
 */
export function isAccountId(subject: string): boolean {
  return /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/.test(
    subject,
  );
}
