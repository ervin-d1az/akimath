import { describe, expect, it } from "vitest";

import { createApp } from "../src/adapters/http-server.js";
import { createLogger, type Logger } from "../src/adapters/logger.js";
import type { SessionVerifier } from "../src/adapters/session-verifier.js";
import { type Caller, CONTRACTED_OPERATIONS, OPS_ROUTES, route } from "../src/routing.js";
import { fakeJwt } from "./support/fake-jwt.js";

const VERSION = "1.2.3";
const NOBODY: Caller = { kind: "absent" };
const LINKED: Caller = { kind: "session", userId: "3f1a2b4c-0000-7000-8000-00000000abcd" };

/**
 * A verifier that reports what it was handed and answers as told.
 *
 * The real one is tested against real Ed25519 keys in
 * `session-verifier.test.ts`. What this file is about is the wiring: that the
 * header reaches the verifier and the verdict reaches `route()`.
 */
function stubVerifier(caller: Caller): SessionVerifier & { seen: (string | undefined)[] } {
  const seen: (string | undefined)[] = [];
  const verify = ((header) => {
    seen.push(header);
    return Promise.resolve(caller);
  }) as SessionVerifier & { seen: (string | undefined)[] };
  verify.seen = seen;
  return verify;
}

/** A logger that keeps its lines instead of printing them. */
function recordingLogger(): Logger & { lines: string[] } {
  const lines: string[] = [];
  const logger = createLogger({
    level: "debug",
    write: (line) => lines.push(line),
    now: () => new Date("2026-08-19T09:15:00.000Z"),
  }) as Logger & { lines: string[] };
  logger.lines = lines;
  return logger;
}

/** A request through the whole adapter, without opening a socket. */
async function call(
  method: string,
  path: string,
  options: { caller?: Caller; header?: string } = {},
): Promise<Response> {
  const request =
    options.header === undefined
      ? new Request(`http://localhost${path}`, { method })
      : new Request(`http://localhost${path}`, {
          method,
          headers: { Authorization: options.header },
        });
  return createApp({
    version: VERSION,
    verify: stubVerifier(options.caller ?? NOBODY),
    log: recordingLogger(),
  }).fetch(request);
}

describe("the transport returns exactly what the policy decided", () => {
  it("for every route the app has, and for one it does not", async () => {
    // **The whole job of this adapter.** A transport that reshaped a status or
    // a body would put the contract parity gate one layer away from what a
    // client actually receives.
    const paths: readonly { method: string; path: string }[] = [
      ...OPS_ROUTES,
      ...CONTRACTED_OPERATIONS.map((operation) => ({
        method: operation.method,
        path: operation.path.replace("{packId}", "2f1c9b0e"),
      })),
      { method: "GET", path: "/nonsense" },
      { method: "PUT", path: "/me" },
    ];

    expect(paths.length).toBeGreaterThan(1);
    for (const { method, path } of paths) {
      const expected = route(method, path, VERSION, NOBODY);
      const response = await call(method, path);

      expect(response.status, `${method} ${path}`).toBe(expected.status);
      expect(await response.json(), `${method} ${path}`).toEqual(expected.body);
    }
  });

  it("every response is JSON", async () => {
    for (const path of ["/health", "/me", "/nonsense"]) {
      const response = await call("GET", path);
      expect(response.headers.get("content-type")).toContain("application/json");
    }
  });
});

describe("the framework does not route", () => {
  it("a path Hono has never heard of still reaches the policy", async () => {
    // Hono's own router is deliberately unused: the surface lives in
    // `CONTRACTED_OPERATIONS` where the parity gate can read it. If Hono were
    // routing, this would be its 404 rather than ours — and ours carries a
    // `message`, which the frozen `Error` schema requires.
    const response = await call("GET", "/a/path/nobody/registered");

    expect(response.status).toBe(404);
    expect(await response.json()).toEqual({
      error: "not_found",
      message: "There is nothing at that path.",
    });
  });

  it("a method Hono would reject reaches it too", async () => {
    const response = await call("PATCH", "/health");

    expect(response.status).toBe(405);
    expect(await response.json()).toMatchObject({ error: "method_not_allowed" });
  });
});

describe("the version it was given is the version it reports", () => {
  it("health carries it", async () => {
    const response = await call("GET", "/health");

    expect(await response.json()).toMatchObject({ version: VERSION });
  });

  it("a query string is not part of the path", async () => {
    // `route` matches on the path alone; a transport that passed the whole URL
    // would turn every link with a `?utm_source` into a 404.
    const response = await createApp({ version: VERSION, verify: stubVerifier(NOBODY), log: recordingLogger() }).fetch(
      new Request("http://localhost/health?from=somewhere"),
    );

    expect(response.status).toBe(200);
  });
});

describe("the credential reaches the verifier and the verdict reaches the policy", () => {
  it("hands the header over without a second opinion about it", async () => {
    // The adapter adds no parsing of its own — a `trim()` or a `toLowerCase()`
    // here would be a second parser competing with the pure one in
    // `session.ts`, and the two would disagree eventually.
    //
    // The value arrives with its outer whitespace already gone: that is the
    // `Headers` API doing what the HTTP spec tells it to, before any of our
    // code runs. Its *inner* shape is untouched, which is the part `session.ts`
    // has opinions about.
    const verify = stubVerifier(NOBODY);
    await createApp({ version: VERSION, verify: verify, log: recordingLogger() }).fetch(
      new Request("http://localhost/me", { headers: { Authorization: "Bearer  weird " } }),
    );
    expect(verify.seen).toEqual(["Bearer  weird"]);
  });

  it("hands over undefined when there is no header at all", async () => {
    const verify = stubVerifier(NOBODY);
    await createApp({ version: VERSION, verify: verify, log: recordingLogger() }).fetch(new Request("http://localhost/me"));
    expect(verify.seen).toEqual([undefined]);
  });

  it("a verified caller gets the answer a verified caller gets", async () => {
    const response = await call("GET", "/me", { caller: LINKED, header: "Bearer good" });
    expect(response.status).toBe(501);
    expect(await response.json()).toEqual(route("GET", "/me", VERSION, LINKED).body);
  });

  it("a refused caller gets the refusal, reason included", async () => {
    const response = await call("GET", "/me", {
      caller: { kind: "refused", why: "the token expired" },
      header: "Bearer stale",
    });
    expect(response.status).toBe(401);
    expect((await response.json()) as { message: string }).toMatchObject({
      message: expect.stringContaining("expired"),
    });
  });

  it("the probe answers whoever asks, credential or not", async () => {
    // `/health` must not depend on the verifier having a key set — the moment it
    // does, a key-server outage looks like a dead application.
    for (const caller of [NOBODY, LINKED, { kind: "refused", why: "x" } as Caller]) {
      expect((await call("GET", "/health", { caller })).status).toBe(200);
    }
  });
});

describe("every request leaves one line", () => {
  it("says what was asked, what was answered, and who asked", async () => {
    const log = recordingLogger();
    await createApp({ version: VERSION, verify: stubVerifier(LINKED), log }).fetch(
      new Request("http://localhost/me", { headers: { Authorization: "Bearer good" } }),
    );

    expect(log.lines).toHaveLength(1);
    expect(JSON.parse(log.lines[0] ?? "null")).toMatchObject({
      level: "info",
      msg: "request",
      method: "GET",
      path: "/me",
      status: 501,
      caller: "session",
    });
  });

  it("names the kind of caller and never the caller", async () => {
    // A user id on every access line is a per-request record of who was awake.
    // The kind is what makes a 401 spike diagnosable, and it is all that does.
    const log = recordingLogger();
    await createApp({ version: VERSION, verify: stubVerifier(LINKED), log }).fetch(
      new Request("http://localhost/me", { headers: { Authorization: "Bearer good" } }),
    );
    expect(log.lines.join("")).not.toContain(LINKED.kind === "session" ? LINKED.userId : "");
  });

  it("the credential never reaches the line, whole or in part", async () => {
    // Belt and braces: the adapter does not log the header, and `log.ts` would
    // redact it if it did. This asserts the outcome rather than either
    // mechanism, so removing one of them fails here.
    const log = recordingLogger();
    const token = fakeJwt();
    await createApp({ version: VERSION, verify: stubVerifier(NOBODY), log }).fetch(
      new Request("http://localhost/me", { headers: { Authorization: `Bearer ${token}` } }),
    );
    expect(log.lines.join("")).not.toContain(token);
  });

  it("a 404 is logged too, because that is the line you go looking for", async () => {
    const log = recordingLogger();
    await createApp({ version: VERSION, verify: stubVerifier(NOBODY), log }).fetch(
      new Request("http://localhost/nope"),
    );
    expect(JSON.parse(log.lines[0] ?? "null")).toMatchObject({ status: 404, path: "/nope" });
  });
});
