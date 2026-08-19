/**
 * One way to write a log line.
 *
 * **PURE** — an event in, a string or `null` out. No clock, no stream, no
 * environment: the adapter beside this supplies all three, which is what lets
 * every rule below be tested by comparing two strings.
 *
 * **One JSON object per line.** It is what an aggregator reads, what `jq`
 * reads, and the only shape that stays parseable when a message contains a
 * newline — so newlines are escaped rather than emitted.
 *
 * **It cannot print a credential**, and that is the reason this is written
 * rather than configured. Redaction runs over *values* as well as field names,
 * because the message is a free string and sooner or later somebody
 * interpolates a token into one. That is not hypothetical: a database password
 * reached a transcript in this repository's own history.
 */

export type LogLevel = "debug" | "info" | "warn" | "error";

export interface LogEvent {
  readonly level: LogLevel;
  readonly message: string;
  readonly at: Date;
  readonly fields?: Readonly<Record<string, unknown>>;
}

const ORDER: readonly LogLevel[] = ["debug", "info", "warn", "error"];
const DEFAULT_LEVEL: LogLevel = "info";

/** The level named by an environment value, and whether one was ignored. */
export function readLogLevel(
  raw: string | undefined,
): { readonly level: LogLevel; readonly ignored?: string } {
  const wanted = (raw ?? "").trim().toLowerCase();
  if (wanted.length === 0) {
    return { level: DEFAULT_LEVEL };
  }
  const found = ORDER.find((level) => level === wanted);
  // **A fallback that announces itself.** Treating `LOG_LEVEL=verbose` as
  // `info` in silence is how somebody spends an afternoon looking for debug
  // lines that were never going to appear.
  return found ? { level: found } : { level: DEFAULT_LEVEL, ignored: wanted };
}

/**
 * The line an event becomes, or `null` if the level filters it out.
 *
 * The three keys that identify a line — `at`, `level`, `msg` — are written
 * last, so a field called `level` cannot turn an error into an info and make
 * the line lie about itself.
 */
export function formatEvent(event: LogEvent, minimum: LogLevel): string | null {
  if (ORDER.indexOf(event.level) < ORDER.indexOf(minimum)) {
    return null;
  }

  const line = {
    ...(redact(event.fields ?? {}, new WeakSet()) as Record<string, unknown>),
    at: event.at.toISOString(),
    level: event.level,
    msg: redactText(event.message),
  };

  return `${JSON.stringify(line)}\n`;
}

/**
 * Field names that make their value a secret whatever it looks like.
 *
 * Matched as a lower-cased substring, so `apiToken`, `SECRET_KEY` and
 * `connectionString` are all caught without anyone maintaining a list of
 * spellings. `session` is deliberately **not** here: `sessionToken` is already
 * caught by `token`, and the bare word would redact `sessionCount` for nothing.
 */
const SECRET_NAMES: readonly string[] = [
  "authorization",
  "credential",
  "cookie",
  "key",
  "passwd",
  "password",
  "secret",
  "token",
];

const REDACTED = "[redacted]";

/** A JWT: three base64url runs, the first opening with a `{"alg"` header. */
const JWT_PATTERN = /eyJ[A-Za-z0-9_-]{4,}\.[A-Za-z0-9_-]{4,}\.[A-Za-z0-9_-]*/g;

/** Anything presented as a bearer credential, JWT or not. */
const BEARER_PATTERN = /\b[Bb]earer\s+\S+/g;

/** The `user:password@` of a URL — the password only; the host stays. */
const USERINFO_PATTERN = /(\w+:\/\/[^\s:/@]+):[^\s@]+@/g;

function isSecretName(name: string): boolean {
  const lower = name.toLowerCase();
  return SECRET_NAMES.some((needle) => lower.includes(needle));
}

/**
 * Replaces credentials inside a string, keeping everything around them.
 *
 * The connection-string case keeps the host and the database on purpose: which
 * server was being reached is the part that makes the line worth writing, and a
 * logger that blanks the whole value teaches people to log around it.
 */
function redactText(value: string): string {
  return value
    .replace(USERINFO_PATTERN, `$1:${REDACTED}@`)
    .replace(BEARER_PATTERN, `Bearer ${REDACTED}`)
    .replace(JWT_PATTERN, REDACTED);
}

/**
 * A value safe to serialise: no credentials, no cycles, nothing `JSON` refuses.
 *
 * **It must not throw.** This runs on the request path, and a logger that
 * throws turns a logged 404 into an unlogged 500.
 */
function redact(value: unknown, seen: WeakSet<object>): unknown {
  if (typeof value === "string") {
    return redactText(value);
  }
  if (typeof value === "bigint") {
    return value.toString();
  }
  if (typeof value === "number") {
    return Number.isFinite(value) ? value : String(value);
  }
  if (typeof value === "boolean" || value === null) {
    return value;
  }
  if (value instanceof Date) {
    return value.toISOString();
  }
  if (value instanceof Error) {
    // `JSON.stringify(new Error("boom"))` is `{}`, which is the least useful
    // line a logger can produce. No stack: it is multi-line and often carries
    // arguments.
    return { name: value.name, message: redactText(value.message) };
  }
  // Functions, symbols and `undefined` land here and are dropped — the caller
  // put something in a log field that cannot be one. There was an explicit
  // guard for the three above this, until mutation testing found every mutant
  // of it surviving: this line already covers them, and `JSON.stringify` omits
  // an `undefined` value from an object anyway.
  if (typeof value !== "object") {
    return undefined;
  }

  if (seen.has(value)) {
    return "[circular]";
  }
  seen.add(value);

  if (Array.isArray(value)) {
    return value.map((item) => redact(item, seen));
  }
  const out: Record<string, unknown> = {};
  for (const [name, item] of Object.entries(value)) {
    out[name] = isSecretName(name) ? REDACTED : redact(item, seen);
  }
  return out;
}
