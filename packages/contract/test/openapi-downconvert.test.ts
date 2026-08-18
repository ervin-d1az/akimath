import { describe, expect, it } from "vitest";
import { z } from "zod";

import {
  CARRIED_THROUGH,
  REWRITTEN,
  toOpenApi303,
} from "../src/openapi/downconvert.js";

/**
 * The down-conversion, tested as a pure function over a JSON document.
 *
 * `ARCHITECTURE.md` §2 pins **OpenAPI 3.0.3** — Zod 4 emits JSON Schema, and
 * 3.0.3 is not JSON Schema. Every row below is a construct Zod actually
 * produces, checked against the installed version rather than assumed; several
 * of them were found by running it rather than by reading about it.
 */
const draft7 = (schema: z.ZodType): unknown =>
  z.toJSONSchema(schema, { target: "draft-7" });

describe("what Zod emits becomes what 3.0.3 admits", () => {
  it("drops the dialect declaration", () => {
    // `$schema` says "this is JSON Schema", which a 3.0.3 document is not.
    const converted = toOpenApi303(draft7(z.object({ a: z.string() }))) as {
      $schema?: unknown;
    };
    expect(converted.$schema).toBeUndefined();
  });

  it("rewrites a nullable union as `nullable: true`", () => {
    // Zod emits `anyOf: [{type: string}, {type: null}]`. 3.0.3 has no null type
    // and no union here — it has a keyword.
    const converted = toOpenApi303(draft7(z.object({ a: z.string().nullable() }))) as {
      properties: { a: Record<string, unknown> };
    };
    expect(converted.properties.a).toEqual({ type: "string", nullable: true });
  });

  it("collapses `const` to a single-valued enum", () => {
    const converted = toOpenApi303(draft7(z.object({ a: z.literal("x") }))) as {
      properties: { a: Record<string, unknown> };
    };
    expect(converted.properties.a).toEqual({ type: "string", enum: ["x"] });
  });

  it("rewrites a numeric exclusive bound as the boolean form", () => {
    // draft-7 says `exclusiveMinimum: 0`. 3.0.3 says `minimum: 0` plus
    // `exclusiveMinimum: true`, which is the draft-4 spelling it inherited.
    const converted = toOpenApi303(draft7(z.object({ a: z.number().gt(0) }))) as {
      properties: { a: Record<string, unknown> };
    };
    expect(converted.properties.a).toEqual({
      type: "number",
      minimum: 0,
      exclusiveMinimum: true,
    });
  });

  it("strips the bounds Zod invents for an unbounded integer", () => {
    // `z.int()` emits ±9007199254740991. That is a fact about JavaScript's safe
    // integer range, not about the API, and it would otherwise be published as
    // a contract every client has to honour.
    const converted = toOpenApi303(draft7(z.object({ a: z.int() }))) as {
      properties: { a: Record<string, unknown> };
    };
    expect(converted.properties.a).toEqual({ type: "integer" });
  });

  it("keeps bounds the author actually wrote", () => {
    // The control for the rule above: stripping by value would silently drop a
    // real `max(20)` the day somebody chose 9007199254740991 on purpose is not
    // the risk — dropping a real bound is.
    const converted = toOpenApi303(draft7(z.object({ a: z.int().min(1).max(20) }))) as {
      properties: { a: Record<string, unknown> };
    };
    expect(converted.properties.a).toEqual({
      type: "integer",
      minimum: 1,
      maximum: 20,
    });
  });

  it("drops `propertyNames`, which 3.0.3 does not have", () => {
    // Found by probing rather than by planning: `z.record(z.string(),
    // z.unknown())` — the shape the frozen pack format already uses for an
    // opaque payload — emits `propertyNames`, and 3.0.3 has no such keyword.
    const converted = toOpenApi303(
      draft7(z.object({ a: z.record(z.string(), z.unknown()) })),
    ) as { properties: { a: Record<string, unknown> } };
    expect(converted.properties.a).toEqual({
      type: "object",
      additionalProperties: {},
    });
  });

  it("rewrites an array-valued type", () => {
    expect(
      toOpenApi303({ type: ["string", "null"] }),
    ).toEqual({ type: "string", nullable: true });
  });

  it("leaves what 3.0.3 already admits alone", () => {
    const untouched = {
      type: "object",
      properties: { a: { type: "string", format: "uuid" } },
      required: ["a"],
      additionalProperties: false,
    };
    expect(toOpenApi303(untouched)).toEqual(untouched);
  });
});

describe("a construct it does not understand is refused, not passed through", () => {
  it("names the keyword and where it was", () => {
    // **The most important test in the file.** A pass-through default is how a
    // 2020-12 construct reaches a Dart client that cannot read it, months
    // later, with every gate green the whole way.
    expect(() =>
      toOpenApi303({ type: "object", properties: { a: { $dynamicRef: "#meta" } } }),
    ).toThrow(/\$dynamicRef.*properties\.a/s);
  });

  it("refuses the 2020-12 keywords by name", () => {
    for (const keyword of ["prefixItems", "$defs", "unevaluatedProperties", "dependentSchemas"]) {
      expect(() => toOpenApi303({ [keyword]: {} }), keyword).toThrow(
        new RegExp(keyword.replace("$", "\\$")),
      );
    }
  });

  it("and accepts every keyword the real schemas use", () => {
    // The control: a converter that refuses everything would pass the two tests
    // above and emit nothing. This is the whole vocabulary the package's own
    // schemas produce.
    const kitchenSink = z.object({
      id: z.uuid(),
      when: z.iso.datetime(),
      count: z.int().min(0),
      ratio: z.number(),
      name: z.string().min(1).max(64),
      flag: z.boolean(),
      kind: z.enum(["a", "b"]),
      list: z.array(z.string()),
      nested: z.object({ inner: z.string() }),
      opaque: z.record(z.string(), z.unknown()),
      maybe: z.string().nullable(),
      fixed: z.literal(7),
    });
    expect(() => toOpenApi303(draft7(kitchenSink))).not.toThrow();
  });
});

describe("the conversion is a pure function", () => {
  it("does not mutate what it is given", () => {
    const input = { type: ["string", "null"] as unknown };
    const before = JSON.stringify(input);
    toOpenApi303(input);
    expect(JSON.stringify(input)).toBe(before);
  });

  it("is idempotent on its own output", () => {
    // A 3.0.3 document run through again must come out unchanged, or emitting
    // twice would drift — which is exactly what the byte-diff gate checks.
    const once = toOpenApi303(draft7(z.object({ a: z.string().nullable(), b: z.int() })));
    expect(toOpenApi303(once)).toEqual(once);
  });
});

describe("the vocabulary is real, entry by entry", () => {
  /** A value each keyword can plausibly hold, so the entry is exercised. */
  const SAMPLE: Readonly<Record<string, unknown>> = {
    type: "string",
    properties: { a: { type: "string" } },
    required: ["a"],
    items: { type: "string" },
    enum: ["a"],
    format: "uuid",
    pattern: "^a$",
    minimum: 1,
    maximum: 2,
    minLength: 1,
    maxLength: 2,
    minItems: 1,
    maxItems: 2,
    uniqueItems: true,
    additionalProperties: false,
    description: "a",
    title: "a",
    default: "a",
    nullable: true,
    deprecated: true,
    readOnly: true,
    writeOnly: true,
    example: "a",
    $ref: "#/components/schemas/X",
  };

  it("every carried-through keyword is genuinely carried through", () => {
    // **Without this the list is unverified.** Most entries are keywords this
    // package's own schemas never produce, so a wrong entry — a typo, a keyword
    // 3.0.3 does not actually admit — would sit there indefinitely. Mutation
    // testing found it as a wall of surviving string literals, which is the
    // report telling the truth: nothing exercised them.
    expect(CARRIED_THROUGH.size).toBeGreaterThan(0);
    for (const keyword of CARRIED_THROUGH) {
      const sample = SAMPLE[keyword];
      expect(sample, `no sample for ${keyword}`).toBeDefined();
      expect(toOpenApi303({ [keyword]: sample }), keyword).toEqual({
        [keyword]: sample,
      });
    }
    // eslint-disable-next-line no-console
    console.log(`  downconvert · ${CARRIED_THROUGH.size} carried, ${REWRITTEN.size} rewritten`);
  });

  it("every rewritten keyword is genuinely rewritten", () => {
    const REWRITES: Readonly<Record<string, { input: unknown; output: unknown }>> = {
      $schema: { input: { $schema: "x", type: "string" }, output: { type: "string" } },
      const: { input: { const: 3 }, output: { enum: [3] } },
      anyOf: {
        input: { anyOf: [{ type: "string" }, { type: "null" }] },
        output: { type: "string", nullable: true },
      },
      exclusiveMinimum: {
        input: { type: "number", exclusiveMinimum: 1 },
        output: { type: "number", minimum: 1, exclusiveMinimum: true },
      },
      exclusiveMaximum: {
        input: { type: "number", exclusiveMaximum: 9 },
        output: { type: "number", maximum: 9, exclusiveMaximum: true },
      },
      propertyNames: {
        input: { type: "object", propertyNames: { type: "string" } },
        output: { type: "object" },
      },
    };

    expect(Object.keys(REWRITES).sort()).toEqual([...REWRITTEN].sort());
    for (const [keyword, { input, output }] of Object.entries(REWRITES)) {
      expect(toOpenApi303(input), keyword).toEqual(output);
    }
  });

  it("a keyword in neither set is refused", () => {
    // The two sets are the whole vocabulary, and this is what makes them closed
    // rather than decorative.
    expect(CARRIED_THROUGH.has("prefixItems")).toBe(false);
    expect(REWRITTEN.has("prefixItems")).toBe(false);
    expect(() => toOpenApi303({ prefixItems: [] })).toThrow(/prefixItems/);
  });
});
