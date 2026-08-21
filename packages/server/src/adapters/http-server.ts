import { randomBytes } from "node:crypto";

import { serve, type ServerType } from "@hono/node-server";
import { Hono, type Context } from "hono";

import { templateRefOf } from "@akimath/core";

import {
  gradeSource,
  readAttemptBatch,
  sourceKey,
  unknownSourceResponse,
  verdictsResponse,
  type Attempt,
  type GradedAttempt,
  type GradingSource,
} from "../attempts.js";
import { difficultyKey, rateAttempts, type RatedAttempt } from "../rating.js";
import { erasureResponse } from "../erasure.js";
import { historyResponse, HISTORY_LIMIT } from "../history.js";
import {
  issuedCopy,
  noSuchPackResponse,
  offlinePackResponse,
  packExpiry,
} from "../packs.js";
import { conflictResponse, linkOutcome, readLinkRequest } from "../link.js";
import { noPlayerResponse, profileResponse } from "../players.js";
import { route, type HandlerAnswer } from "../routing.js";
import { standingResponse } from "../standing.js";
import type { Logger } from "./logger.js";
import { recentSessions } from "./history-repository.js";
import { skillRatings } from "./standing-repository.js";
import { insertPack, packFor } from "./pack-repository.js";
import { shippedPacks, type ShippedPack } from "./shipped-packs.js";
import {
  entryForPackItem,
  insertAttempts,
  refForIssuedItem,
  type AttemptRow,
} from "./attempt-repository.js";
import {
  accountForPlayer,
  deletePlayerForAccount,
  findPlayerForAccount,
  insertPlayer,
  playerIdForAccount,
} from "./player-repository.js";
import {
  lockPlayerRating,
  measuredDifficulties,
  storedSkills,
  writeDifficulties,
  writeSkills,
} from "./rating-repository.js";
import type { RequestDatabase } from "./request-database.js";
import type { SessionVerifier } from "./session-verifier.js";

/**
 * What each implemented operation does, keyed by the contract's `operationId`.
 *
 * **The router chose the key; this only holds the function.** Keeping the
 * surface in `routing.ts` is what leaves it inside `contract-parity.test.ts`'s
 * reach — the same trade this file already makes by not using Hono's router.
 * `IMPLEMENTED_OPERATIONS` and these keys are held equal by a test, so a
 * handler with no route, or a route promising a handler that is not here,
 * fails rather than 500s.
 */
/**
 * What a handler is given.
 *
 * **The whole request, not just the caller.** `getMe` needs only the account,
 * and `linkPlayer` needs a body and a header the contract marks required — a
 * seam shaped for the first would have to be widened for the second anyway, and
 * widening it later means touching every handler.
 */
export interface HandlerRequest {
  /** The `sub` of a verified token. Never anything the body said. */
  readonly userId: string;
  readonly body: unknown;
  readonly header: (name: string) => string | undefined;
  /** The path's own parameters, named by the route template that matched. */
  readonly parameters: Readonly<Record<string, string>>;
}

export type Handlers = Readonly<
  Record<string, (request: HandlerRequest) => Promise<HandlerAnswer>>
>;

/**
 * The two things a handler cannot compute.
 *
 * **Injected, not imported.** Issuing a pack needs a clock and a source of
 * randomness, and a module that reaches for either is one no test can pin.
 * Defaults come from the platform, so the production wiring says nothing.
 */
export interface HandlerEnvironment {
  readonly now: () => Date;
  /** Lowercase hex, `bytes` long in bytes. The pack salt is sixteen. */
  readonly randomHex: (bytes: number) => string;
  /** A signed 64-bit seed, matching `issued_items.seed` and the manifest. */
  readonly randomSeed: () => bigint;
  /**
   * The packs this build can issue, read on first use.
   *
   * A function rather than a map, so a bad artifact fails where a test can see
   * it instead of at import (PROC-5 step 0b), and so a test can hand over one
   * of its own without touching the filesystem.
   */
  readonly shippedPacks: () => ReadonlyMap<string, ShippedPack>;
}

const PLATFORM: HandlerEnvironment = {
  now: () => new Date(),
  randomHex: (bytes) => randomBytes(bytes).toString("hex"),
  // Read as unsigned and shifted into the signed range, so the whole column is
  // reachable — a generator that only ever produced positives would exercise
  // half the seed space and hide every sign bug in rederivation.
  randomSeed: () => BigInt.asIntN(64, randomBytes(8).readBigUInt64BE()),
  shippedPacks,
};

/**
 * Which shipped pack a new issuance is a copy of.
 *
 * One today. When there are several, choosing between them is a product
 * decision — and it is the same decision as "which pack does this player need
 * next", which is rating's, which is F4.
 */
const ISSUED_CONTENT = "starter";

export function createHandlers(
  database: RequestDatabase,
  environment: HandlerEnvironment = PLATFORM,
): Handlers {
  return {
    getMe: ({ userId }) =>
      database.inRequestRole(async (client) =>
        profileResponse(await findPlayerForAccount(client, userId)),
      ),

    // **The one handler that does not run as `app_request`.** That role holds
    // DELETE on no table, deliberately; erasure is the sanctioned exception and
    // runs under `retention_job`, which is exactly what `CLAUDE.md`'s
    // append-only invariant says the erasure path does.
    deleteMe: ({ userId }) =>
      database.inErasureRole(async (client) =>
        erasureResponse(await deletePlayerForAccount(client, userId)),
      ),

    // **The server grades; the client only reports what it typed.** §4's
    // invariant is that no field on a submission asserts a verdict, so the
    // answer is checked by rederiving the item from the reference the database
    // recorded — `readAttemptBatch` refuses a body that carries one anyway.
    submitAttempts: async ({ userId, body }) => {
      const read = readAttemptBatch(body);
      // `"status" in read`, not `Array.isArray`: the latter widens a
      // `readonly Attempt[]` to `any[]` and leaves the other branch un-narrowed.
      if ("status" in read) {
        return read;
      }

      return database.inRequestRole(async (client) => {
        const playerId = await playerIdForAccount(client, userId);
        if (playerId === null) {
          return noPlayerResponse();
        }

        // **The rating reads and writes here, so the whole batch is
        // serialised against this player.** `ARCHITECTURE.md` §5: the Glicko
        // computation sits between the INSERT and the `user_skills` upsert, and
        // two devices syncing at once would otherwise both read the same prior
        // and one update would be lost. Taken before the first read, or the
        // lock protects nothing.
        await lockPlayerRating(client, playerId);

        // **Every source resolved before anything is written.** A batch is one
        // transaction and one answer; recording the first forty and refusing
        // the forty-first would leave the client unable to tell what landed.
        const graded: GradedAttempt[] = [];
        const rows: AttemptRow[] = [];
        const steps = new Map<string, number | null>();
        for (const [index, attempt] of read.entries()) {
          const found = await gradingSourceFor(
            client,
            playerId,
            attempt,
            environment.shippedPacks(),
          );
          if (found === null) {
            return unknownSourceResponse(index);
          }
          // One call for both facts: the skill comes from the template on one
          // path and from the manifest on the other, and the branch belongs
          // where the grading is rather than here.
          const { ok, skillId } = gradeSource(found.source, attempt.answer);
          graded.push({ source: attempt.source, ok });
          steps.set(sourceKey(attempt.source), found.ladderStep);
          rows.push({
            playerId,
            source: attempt.source,
            sessionId: attempt.sessionId,
            skillId,
            isCorrect: ok,
            elapsedMs: attempt.elapsedMs,
            answeredAt: attempt.clientTs,
          });
        }

        const landed = new Set(
          (await insertAttempts(client, rows)).map((source) => sourceKey(source)),
        );
        await applyRating(client, playerId, environment.now(), landedRows(rows, steps, landed));

        return verdictsResponse(graded);
      });
    },

    // **A history entry is a session, not an attempt.** The frozen shape asks
    // for a score and a title, and neither means anything about one answered
    // item — which is why `session_id` had to be persisted first (0004).
    getHistory: ({ userId }) =>
      database.inRequestRole(async (client) => {
        const playerId = await playerIdForAccount(client, userId);
        if (playerId === null) {
          return noPlayerResponse();
        }
        return historyResponse(await recentSessions(client, playerId, HISTORY_LIMIT));
      }),

    // **The standing is the rating, and there is no rating yet.** The frozen
    // `Standing` carries `{skillId, rating, deviation, updatedAt}` and has no
    // field for accuracy or time on task, derivable from `attempts` though both
    // are — so this answers what the shape holds and nothing else. Nothing
    // writes `user_skills`, which makes the list empty for every player today;
    // that is read from the table rather than hard-coded, so the day a rating
    // job writes a row this endpoint already reports it.
    getStanding: ({ userId }) =>
      database.inRequestRole(async (client) => {
        const playerId = await playerIdForAccount(client, userId);
        if (playerId === null) {
          return noPlayerResponse();
        }
        return standingResponse(playerId, await skillRatings(client, playerId));
      }),

    // **A re-fetch rebuilds rather than reads a body.** `offline_packs` stores
    // a manifest and a salt, not fifty rows of rendered item — that is
    // `ARCHITECTURE.md` §4's whole reason for the manifest — so the pack is
    // reconstructed from what is stored. Every digest comes back identical.
    getOfflinePack: ({ userId, parameters }) =>
      database.inRequestRole(async (client) => {
        const packId = parameters["packId"] ?? "";
        const playerId = await playerIdForAccount(client, userId);
        if (playerId === null) {
          return noPlayerResponse();
        }
        const stored = await packFor(client, playerId, packId);
        if (stored === null) {
          return noSuchPackResponse();
        }

        // **Rebuilt from the content it names, never read back from a body.**
        // The artifact is 158 KB and it is the same 158 KB for every player, so
        // the row records which pack it is a copy of and the two instants that
        // are its own. Neither instant is digested, so nothing an attempt is
        // graded against moves.
        //
        // Every row has a `content_id`: `POST /packs` is the only thing that
        // writes one and it always issues a copy. A row without one would be a
        // pack this build cannot describe, and it is answered the same way as
        // content the build no longer ships.
        const content =
          stored.contentId === null
            ? undefined
            : environment.shippedPacks().get(stored.contentId);
        if (content === undefined) {
          // The build no longer ships it. A 404 is the honest answer: the row
          // is real and the content is gone, and there is nothing the caller
          // can do that a different status would help with.
          return noSuchPackResponse();
        }
        return offlinePackResponse(
          packId,
          issuedCopy({
            content: content.pack,
            issuedAt: stored.issuedAt,
            expiresAt: stored.expiresAt,
          }),
        );
      }),

    // **Issuing is the first step of the offline loop, and nothing had one.**
    // `GET /packs/{packId}` fetched by an id that nothing minted, so
    // `offline_packs` could only ever be empty and a pack attempt could never
    // reach `POST /attempts`.
    issuePack: ({ userId }) =>
      database.inRequestRole(async (client) => {
        const playerId = await playerIdForAccount(client, userId);
        if (playerId === null) {
          return noPlayerResponse();
        }

        // **A copy of the content the app already ships**, not twenty
        // generated subtractions. `issuedPack` still exists and still works;
        // nothing should prefer it while there is one template family, and
        // 0005 is what made the better pack gradeable at all.
        const content = environment.shippedPacks().get(ISSUED_CONTENT);
        if (content === undefined) {
          // Unreachable while the build ships one, and thrown rather than
          // answered: a server with no content is not a client's problem.
          throw new Error(`this build ships no pack called "${ISSUED_CONTENT}"`);
        }

        const issuedAt = environment.now();
        const expiresAt = packExpiry(issuedAt);
        const issued = issuedCopy({ content: content.pack, issuedAt, expiresAt });

        const packId = await insertPack(client, {
          playerId,
          contentId: content.id,
          // One skill per issued pack today, and the column is nullable for the
          // day that stops being true. Taken from the items rather than assumed.
          skillId: issued.pack.skill_nodes[0]!.skill_id,
          manifest: issued.manifest,
          saltHex: issued.pack.pack_salt,
          issuedAt,
          expiresAt,
        });

        return offlinePackResponse(packId, issued);
      }),

    linkPlayer: async ({ userId, body, header }) => {
      const request = readLinkRequest(body, header("Idempotency-Key"));
      if ("status" in request) {
        return request;
      }

      // **One transaction for both reads and the write.** Two callers linking
      // the same player at once would otherwise both see no row and both try to
      // insert; the loser gets a constraint violation instead of the 409 the
      // contract describes.
      return database.inRequestRole(async (client) => {
        const outcome = linkOutcome({
          request,
          accountId: userId,
          playerForAccount: await playerIdForAccount(client, userId),
          accountForPlayer: await accountForPlayer(client, request.playerId),
        });

        switch (outcome.kind) {
          case "conflict":
            return conflictResponse(outcome.why);
          case "existing":
            // Idempotent by nature: the row it would have written is the row
            // that is already there.
            return profileResponse(await findPlayerForAccount(client, userId));
          case "create":
            return profileResponse(
              await insertPlayer(client, {
                id: request.playerId,
                ageBand: request.ageBand,
                accountId: userId,
              }),
            );
        }
      });
    },
  };
}

/**
 * The answers that actually reached the table, as the rating sees them.
 *
 * **Only what landed.** `insertAttempts` says `ON CONFLICT DO NOTHING`, so a
 * resent batch writes nothing — and a rating fed the *submitted* rows would
 * move twice for one answer, on a table the request path can neither update nor
 * delete. There would be nothing to repair it with.
 */
function landedRows(
  rows: readonly AttemptRow[],
  steps: ReadonlyMap<string, number | null>,
  landed: ReadonlySet<string>,
): readonly RatedAttempt[] {
  return rows
    .filter((row) => landed.has(sourceKey(row.source)))
    .map((row) => ({
      sessionId: row.sessionId,
      skillId: row.skillId,
      ladderStep: steps.get(sourceKey(row.source)) ?? null,
      isCorrect: row.isCorrect,
      answeredAt: new Date(row.answeredAt),
    }));
}

/**
 * Rates what landed, and writes both sides of it.
 *
 * The player and the difficulty classes are measured against each other, so
 * they are read and written together — reading the classes after the player had
 * already been updated would rate one half of an observation against the other
 * half's result.
 */
async function applyRating(
  // The client type spelled the way `gradingSourceFor` spells it, so this file
  // still imports no `pg`: the socket belongs to the repositories.
  client: Parameters<typeof storedSkills>[0],
  playerId: string,
  now: Date,
  attempts: readonly RatedAttempt[],
): Promise<void> {
  if (attempts.length === 0) {
    return;
  }
  const skillIds = [...new Set(attempts.map((one) => one.skillId))];
  const wanted = [
    ...new Map(
      attempts
        .filter((one) => one.ladderStep !== null)
        .map((one) => [
          difficultyKey(one.skillId, one.ladderStep!),
          { skillId: one.skillId, ladderStep: one.ladderStep! },
        ]),
    ).values(),
  ];

  const update = rateAttempts({
    attempts,
    skills: await storedSkills(client, playerId, skillIds),
    difficulties: await measuredDifficulties(client, wanted),
    now,
  });

  await writeSkills(client, playerId, update.skills);
  await writeDifficulties(client, update.difficulties);
}

/**
 * What an attempt's answer is checked against, and how hard the item was.
 *
 * An issued item is always a template — that is what `issued_items` holds. A
 * pack item is whatever the manifest says it is: a template to rederive, or a
 * digest to verify, which is the only way authored content can be graded.
 *
 * **The ladder step travels with the source because only this function can
 * find it.** It names the difficulty class the rating measures against, and it
 * lives in three different places: on a template reference directly, and — for
 * a digest entry, which records no difficulty at all — in the shipped content
 * the pack row names. Resolving it anywhere else would mean a second reader for
 * each of those.
 *
 * It is `null` when nothing recorded says: a pack that names no content has an
 * item whose difficulty this server genuinely does not know, and the rating is
 * told so rather than handed a default.
 */
interface AttemptSourceAndStep {
  readonly source: GradingSource;
  readonly ladderStep: number | null;
}

async function gradingSourceFor(
  client: Parameters<typeof refForIssuedItem>[0],
  playerId: string,
  attempt: Attempt,
  content: ReadonlyMap<string, ShippedPack>,
): Promise<AttemptSourceAndStep | null> {
  if (attempt.source.kind === "issued") {
    const ref = await refForIssuedItem(client, playerId, attempt.source.itemId);
    return ref === null
      ? null
      : { source: { kind: "template", ref }, ladderStep: ref.ladderStep };
  }

  const found = await entryForPackItem(
    client,
    playerId,
    attempt.source.packId,
    attempt.source.index,
  );
  if (found === null) {
    return null;
  }
  const ref = templateRefOf(found.entry);
  if (ref !== null) {
    return { source: { kind: "template", ref }, ladderStep: ref.ladderStep };
  }
  const entry = found.entry as Extract<typeof found.entry, { kind: "digest" }>;
  return {
    source: {
      kind: "digest",
      digest: entry.digest,
      saltHex: found.saltHex,
      skillId: entry.skill_id,
    },
    ladderStep: stepInContent(content, found.contentId, attempt.source.index),
  };
}

/**
 * The difficulty the shipped content records at that position.
 *
 * The manifest is built from `content.items` in order and one entry per item,
 * which is the same alignment `getOfflinePack` rebuilds a pack on — so the
 * attempt's index addresses the content directly.
 *
 * Null rather than a guess at every step: a pack naming no content, a build
 * that no longer ships that content, and an index past the end are all "this
 * server cannot say how hard that was", and the rating leaves such an answer
 * out and counts it.
 */
function stepInContent(
  content: ReadonlyMap<string, ShippedPack>,
  contentId: string | null,
  index: number,
): number | null {
  if (contentId === null) {
    return null;
  }
  return content.get(contentId)?.pack.items[index]?.ladder_step ?? null;
}

/**
 * The boundary that owns the socket.
 *
 * **Hono transports; `route()` decides.** Hono has a router of its own and it
 * is deliberately not used for the app's paths — the surface lives in
 * `CONTRACTED_OPERATIONS`, where `contract-parity.test.ts` holds it to
 * `contract/openapi.json` in both directions. Registering the routes with Hono
 * instead would move that surface somewhere the gate cannot read, and trade a
 * checked contract for a framework's convenience.
 *
 * So this is one catch-all handler that hands method and path to the pure
 * policy and returns what it says. What Hono is *for* is everything around
 * that: web-standard `Request`/`Response`, a JSON body parser for the
 * operations that will take one, and a middleware chain for the session check
 * that arrives with linking — none of which `node:http` gives without being
 * hand-written, and one of which is authentication, which `CLAUDE.md` forbids
 * hand-writing.
 *
 * It also drops two defaults the old adapter needed. `request.url ?? "/"` and
 * `request.method ?? "GET"` were papering over a `node:http` type, and a
 * request with no method silently became a `GET` of `/health`.
 *
 * **The verifier and the logger are injected**, so this file holds no key set,
 * no URL and no stream. The one thing it does with a credential is resolve it
 * before routing: `route()` is synchronous and pure, and verification is
 * neither.
 */
export interface AppOptions {
  readonly version: string;
  readonly verify: SessionVerifier;
  readonly log: Logger;
  readonly handlers: Handlers;
}

export function createApp({ version, verify, log, handlers }: AppOptions): Hono {
  const app = new Hono();

  app.all("*", async (context) => {
    const startedAt = Date.now();
    const path = new URL(context.req.url).pathname;
    // **Resolved for every request, including the ones that will 404.** The
    // alternative is to route first and verify only when the path matched,
    // which makes the answer to "does this path exist" measurably faster for an
    // unauthenticated caller than for an authenticated one. The paths are all
    // published in `contract/openapi.json`, so the leak is small — and so is
    // the cost of not having it, since a verified key set is cached in memory.
    const caller = await verify(context.req.header("Authorization"));
    const decision = route(context.req.method, path, version, caller);
    const result =
      decision.kind === "answer"
        ? decision.response
        : await run(handlers, decision.operationId, log, {
            userId: decision.userId,
            body: await readJsonBody(context),
            header: (name) => context.req.header(name),
            parameters: decision.parameters,
          });

    // **One line per request, and `caller` is the kind rather than the who.**
    // A user id in every access line is a per-request record of who was awake;
    // the kind is what makes a 401 spike diagnosable, and it is all that does.
    // The token cannot appear here even by accident — `log.ts` redacts values,
    // not only field names.
    log.info("request", {
      method: context.req.method,
      path,
      status: result.status,
      caller: caller.kind,
      operation: decision.kind === "dispatch" ? decision.operationId : undefined,
      ms: Date.now() - startedAt,
    });

    // **`body` present or absent, not a status check.** A 204 built with
    // `context.json` throws inside the Fetch `Response` constructor — a null-body
    // status cannot carry one — and it throws here, outside `run()`'s try/catch,
    // so the client would get Hono's 500 rather than the answer the handler gave.
    return "body" in result
      ? context.json(result.body as Record<string, unknown>, result.status as ContentfulStatus)
      : context.body(null, result.status);
  });

  return app;
}

/**
 * Runs a handler, and turns anything it throws into a 500 that says nothing.
 *
 * **The message never reaches the client.** A database error quotes the SQL it
 * failed on, which is a schema description handed to whoever asked. It goes to
 * the log instead, where the redactor has already been over it.
 */
/**
 * The JSON body, or undefined where there is none.
 *
 * Never throws: a malformed body is the handler's to refuse with a 400 that
 * says so, not the transport's to turn into a 500.
 */
async function readJsonBody(context: Context): Promise<unknown> {
  try {
    return await context.req.json();
  } catch {
    return undefined;
  }
}

async function run(
  handlers: Handlers,
  operationId: string,
  log: Logger,
  request: HandlerRequest,
): Promise<HandlerAnswer> {
  const handler = handlers[operationId];
  if (handler === undefined) {
    // Unreachable while `test/every-built-operation-has-a-handler.test.ts`
    // passes — the gate this comment claimed for months before anybody wrote
    // it. Answered rather than thrown so that if it ever *is* reached, it is
    // one bad endpoint rather than a crashed process.
    log.error("routed to a handler that does not exist", { operation: operationId });
    return { status: 500, body: { error: "internal", message: "That went wrong on our side." } };
  }

  try {
    return await handler(request);
  } catch (cause) {
    log.error("handler failed", { operation: operationId, cause });
    return { status: 500, body: { error: "internal", message: "That went wrong on our side." } };
  }
}

/** Every status `route()` and its handlers can return. Hono types its own set. */
type ContentfulStatus = 200 | 400 | 401 | 404 | 405 | 409 | 500 | 501;

export function startHttpServer(options: AppOptions & { readonly port: number }): ServerType {
  return serve({ fetch: createApp(options).fetch, port: options.port });
}
