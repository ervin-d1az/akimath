import { z } from "zod";

import { API_SCHEMAS } from "./api-schemas.js";
import { toOpenApi303 } from "./downconvert.js";

/**
 * The committed API specification, as a value.
 *
 * **PURE** — no filesystem, no environment, no framework. `ARCHITECTURE.md` §2 is
 * explicit about why that matters: "`packages/contract` exists so the spec can be
 * emitted **without booting Hono or touching `DATABASE_URL`** — if emitting the
 * spec needs a database the CI gate goes flaky and gets disabled."
 *
 * **OpenAPI 3.0.3**, per the same section: Zod emits JSON Schema and no mature
 * Dart generator digests 3.1 well. The gap is closed by `downconvert.ts`, which
 * runs over each schema; the envelope below is assembled around the results.
 *
 * No endpoint here is implemented. This describes what `f3-server-foundation`
 * will serve, which is the point of freezing it first — ADR 0001 makes the Dart
 * client hand-written, so this document is the only thing that can keep it
 * honest.
 */
export const OPENAPI_VERSION = "3.0.3";
export const API_VERSION = "0.1.0";

const ref = (name: keyof typeof API_SCHEMAS): { $ref: string } => ({
  $ref: `#/components/schemas/${name}`,
});

const json = (schema: { $ref: string }): unknown => ({
  content: { "application/json": { schema } },
});

const errors = {
  "400": { description: "The request was malformed.", ...(json(ref("Error")) as object) },
  "401": { description: "No valid session.", ...(json(ref("Error")) as object) },
  "404": { description: "No such resource.", ...(json(ref("Error")) as object) },
  // A response to a request that matched a *path* and no operation on it, so it
  // belongs to none of them and is declared on all of them — the conventional
  // OpenAPI workaround. Declared rather than assumed, because the router
  // returns it and a status the contract does not describe is drift.
  "405": { description: "That method is not routed here.", ...(json(ref("Error")) as object) },
};

export function buildOpenApiDocument(): unknown {
  const schemas: Record<string, unknown> = {};
  for (const [name, schema] of Object.entries(API_SCHEMAS)) {
    schemas[name] = toOpenApi303(
      z.toJSONSchema(schema as z.ZodType, { target: "draft-7" }),
    );
  }

  return {
    openapi: OPENAPI_VERSION,
    info: {
      title: "AkiMath API",
      version: API_VERSION,
      description:
        "The prompt travels rendered. The answer never travels online. Offline, " +
        "a membership verifier travels and its verdict is provisional until sync.",
    },
    servers: [{ url: "/v1" }],
    paths: {
      "/items/next": {
        get: {
          operationId: "getNextItem",
          summary: "The next item to show, already rendered.",
          responses: {
            "200": {
              description: "An item.",
              ...(json(ref("ItemResponse")) as object),
            },
            ...errors,
          },
        },
      },
      "/attempts": {
        post: {
          operationId: "submitAttempts",
          summary: "Submit a session's attempts and receive their verdicts.",
          requestBody: {
            required: true,
            ...(json(ref("AttemptBatch")) as object),
          },
          responses: {
            "200": {
              description: "One verdict per attempt, in the order submitted.",
              ...(json(ref("VerdictBatch")) as object),
            },
            ...errors,
          },
        },
      },
      "/packs/{packId}": {
        get: {
          operationId: "getOfflinePack",
          summary: "An issued offline pack.",
          parameters: [
            {
              name: "packId",
              in: "path",
              required: true,
              schema: { type: "string", format: "uuid" },
            },
          ],
          responses: {
            "200": {
              description: "The pack.",
              ...(json(ref("OfflinePack")) as object),
            },
            ...errors,
          },
        },
      },
      "/players/link": {
        post: {
          operationId: "linkPlayer",
          summary: "Attach a locally-minted player to the current account.",
          parameters: [
            {
              name: "Idempotency-Key",
              in: "header",
              required: true,
              schema: { type: "string" },
            },
          ],
          requestBody: {
            required: true,
            ...(json(ref("PlayerLink")) as object),
          },
          responses: {
            "200": { description: "Linked.", ...(json(ref("Me")) as object) },
            ...errors,
          },
        },
      },
      "/me": {
        get: {
          operationId: "getMe",
          summary: "The current player.",
          responses: {
            "200": { description: "The player.", ...(json(ref("Me")) as object) },
            ...errors,
          },
        },
        delete: {
          operationId: "deleteMe",
          summary: "Erase the player and everything recorded about them.",
          responses: {
            "204": { description: "Erased." },
            ...errors,
          },
        },
      },
      "/me/standing": {
        get: {
          operationId: "getStanding",
          summary: "The player's rating per skill.",
          responses: {
            "200": {
              description: "The standing.",
              ...(json(ref("Standing")) as object),
            },
            ...errors,
          },
        },
      },
      "/me/history": {
        get: {
          operationId: "getHistory",
          summary: "Recent series and puzzles.",
          responses: {
            "200": {
              description: "The history.",
              ...(json(ref("History")) as object),
            },
            ...errors,
          },
        },
      },
    },
    components: { schemas },
  };
}
