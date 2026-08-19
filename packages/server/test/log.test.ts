import { describe, expect, it } from "vitest";

import { formatEvent, readLogLevel, type LogEvent } from "../src/log.js";
import { fakeJwt } from "./support/fake-jwt.js";

const AT = new Date("2026-08-19T09:15:00.000Z");

const parse = (line: string | null): Record<string, unknown> =>
  JSON.parse(line ?? "null") as Record<string, unknown>;

const event = (over: Partial<LogEvent> = {}): LogEvent => ({
  level: "info",
  message: "something happened",
  at: AT,
  ...over,
});

describe("one line, one event", () => {
  it("is JSON, with the time, the level and the message", () => {
    // One JSON object per line is what every aggregator reads and what `jq`
    // reads, and it is the only format that stays parseable when a message
    // contains a newline.
    expect(parse(formatEvent(event(), "debug"))).toEqual({
      at: "2026-08-19T09:15:00.000Z",
      level: "info",
      msg: "something happened",
    });
  });

  it("carries its fields at the top level, where a query can reach them", () => {
    expect(
      parse(formatEvent(event({ fields: { status: 501, path: "/me" } }), "debug")),
    ).toMatchObject({ status: 501, path: "/me" });
  });

  it("a field never overwrites the three that identify the line", () => {
    // Otherwise a field called `level` turns an error into whatever it says,
    // and the line lies about itself.
    const line = parse(
      formatEvent(
        event({ level: "error", fields: { level: "info", msg: "nope", at: "1999" } }),
        "debug",
      ),
    );
    expect(line).toMatchObject({ level: "error", msg: "something happened" });
    expect(line["at"]).toBe("2026-08-19T09:15:00.000Z");
  });

  it("never emits a newline inside the line", () => {
    const line = formatEvent(
      event({ message: "line one\nline two", fields: { detail: "a\nb" } }),
      "debug",
    );
    expect(line).not.toBeNull();
    expect(line?.slice(0, -1)).not.toContain("\n");
  });

  it("ends with exactly one newline, so two writes cannot share a line", () => {
    expect(formatEvent(event(), "debug")?.endsWith("}\n")).toBe(true);
  });
});

describe("what the level is for", () => {
  it("drops anything below the minimum", () => {
    expect(formatEvent(event({ level: "debug" }), "info")).toBeNull();
    expect(formatEvent(event({ level: "info" }), "warn")).toBeNull();
    expect(formatEvent(event({ level: "warn" }), "error")).toBeNull();
  });

  it("keeps the minimum itself and everything above it", () => {
    // The control: a filter that dropped everything would satisfy the test
    // above and would be a server that logs nothing.
    for (const level of ["info", "warn", "error"] as const) {
      expect(formatEvent(event({ level }), "info"), level).not.toBeNull();
    }
  });

  it("reads a level from the environment, however it was typed", () => {
    // All four levels by name, because a list with a typo in its first entry
    // still reads correctly for the other three.
    for (const level of ["debug", "info", "warn", "error"] as const) {
      expect(readLogLevel(level), level).toEqual({ level });
    }
    // Environment values arrive from shells and CI panes: padded, shouted, both.
    expect(readLogLevel("  WARN  ")).toEqual({ level: "warn" });
    expect(readLogLevel(undefined)).toEqual({ level: "info" });
    expect(readLogLevel("")).toEqual({ level: "info" });
    expect(readLogLevel("   ")).toEqual({ level: "info" });
  });

  it("an unrecognised level falls back, but does not do it quietly", () => {
    // Silently treating `LOG_LEVEL=verbose` as `info` is how somebody spends an
    // afternoon wondering where their debug lines went.
    expect(readLogLevel("verbose")).toEqual({ level: "info", ignored: "verbose" });
  });
});

describe("the logger cannot print a credential", () => {
  // This is the reason this module is hand-written rather than configured, and
  // the reason redaction runs over *values* and not only over field names: the
  // message is a free string, and sooner or later somebody interpolates a token
  // into one.

  const JWT = fakeJwt();

  it("redacts a field whose name says it is a secret", () => {
    const line = formatEvent(
      event({
        fields: {
          password: "hunter2",
          apiToken: "abc",
          Authorization: "Bearer x",
          connectionString: "postgres://u:p@h/db",
          SECRET_KEY: "s",
        },
      }),
      "debug",
    );
    expect(line).not.toBeNull();
    for (const leaked of ["hunter2", "abc", "Bearer x", "postgres://u:p@h/db", '"s"']) {
      expect(line, leaked).not.toContain(leaked);
    }
  });

  it("redacts a JWT wherever it appears, message included", () => {
    // The exact result, not merely "the token is gone": a redactor that
    // replaced the whole message with an empty string would also pass that.
    expect(parse(formatEvent(event({ message: `verifying ${JWT}` }), "debug"))["msg"]).toBe(
      "verifying [redacted]",
    );
    expect(
      parse(formatEvent(event({ fields: { note: `saw ${JWT} once` } }), "debug"))["note"],
    ).toBe("saw [redacted] once");
  });

  it("redacts a JWT with an empty signature, which is how `alg: none` is spelled", () => {
    expect(
      parse(
        formatEvent(
          event({ message: `token ${fakeJwt({ claims: { sub: "a" }, signature: "" })} here` }),
          "debug",
        ),
      )["msg"],
    ).toBe("token [redacted] here");
  });

  it("redacts the password out of a connection string, and keeps the rest", () => {
    // The whole value is not thrown away: which host and which database were
    // being reached is the part that makes the line worth logging.
    expect(
      parse(
        formatEvent(
          event({ message: "connecting to postgresql://neondb_owner:npg_secret@ep-x.aws/neondb" }),
          "debug",
        ),
      )["msg"],
    ).toBe("connecting to postgresql://neondb_owner:[redacted]@ep-x.aws/neondb");
  });

  it("redacts a bearer header however much whitespace it was given", () => {
    for (const spacing of [" ", "   ", "\t"]) {
      expect(
        parse(formatEvent(event({ message: `sent Bearer${spacing}opaque-token` }), "debug"))["msg"],
      ).toBe("sent Bearer [redacted]");
    }
  });

  it("reaches into nested objects and arrays", () => {
    const line = formatEvent(
      event({ fields: { request: { headers: { authorization: `Bearer ${JWT}` } }, tried: [JWT] } }),
      "debug",
    );
    expect(line).not.toContain(JWT);
  });

  it("a bare Bearer header value is redacted even without a JWT in it", () => {
    expect(
      parse(formatEvent(event({ message: "sent Authorization: Bearer opaque-here" }), "debug"))[
        "msg"
      ],
    ).toBe("sent Authorization: Bearer [redacted]");
  });
});

describe("it never throws, and says exactly what it kept", () => {
  // Asserted as values rather than as "it did not throw": a formatter that
  // dropped every field would not throw either, and that is the failure mode
  // worth catching in a logger.

  const fieldsOf = (fields: Record<string, unknown>): Record<string, unknown> => {
    const line = parse(formatEvent(event({ fields }), "debug"));
    delete line["at"];
    delete line["level"];
    delete line["msg"];
    return line;
  };

  it("survives a cycle, and marks where it turned back", () => {
    // `JSON.stringify` throws on one, and a logger that throws turns a logged
    // 404 into an unlogged 500.
    const cyclic: Record<string, unknown> = { name: "loop" };
    cyclic["self"] = cyclic;
    expect(fieldsOf({ cyclic })).toEqual({ cyclic: { name: "loop", self: "[circular]" } });
  });

  it("keeps the values JSON would refuse, in a readable shape", () => {
    expect(fieldsOf({ big: BigInt(7), nan: Number.NaN, huge: Number.POSITIVE_INFINITY })).toEqual({
      big: "7",
      nan: "NaN",
      huge: "Infinity",
    });
  });

  it("drops the values that cannot be a log field at all", () => {
    // A function or a symbol in a log line is a bug in the caller; the line
    // still goes out, without them.
    expect(fieldsOf({ fn: () => undefined, sym: Symbol("s"), undef: undefined })).toEqual({});
  });

  it("keeps booleans, null and numbers as themselves", () => {
    // The control for the branch above: "drops everything" would satisfy it.
    expect(fieldsOf({ yes: true, no: false, nothing: null, count: 0 })).toEqual({
      yes: true,
      no: false,
      nothing: null,
      count: 0,
    });
  });

  it("keeps an array's contents, in order", () => {
    expect(fieldsOf({ tried: ["a", 1, true, null] })).toEqual({ tried: ["a", 1, true, null] });
  });

  it("writes a date as an instant, not as an object", () => {
    expect(fieldsOf({ when: new Date("2026-01-02T03:04:05.000Z") })).toEqual({
      when: "2026-01-02T03:04:05.000Z",
    });
  });

  it("logs an error as a name and a message rather than as {}", () => {
    // `JSON.stringify(new Error("boom"))` is `{}`, which is the least useful
    // line a logger can emit.
    expect(fieldsOf({ cause: new TypeError("boom") })).toEqual({
      cause: { name: "TypeError", message: "boom" },
    });
  });
});
