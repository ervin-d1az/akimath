import { existsSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";

/**
 * The frozen contract, read from the emitted artifact rather than from the
 * TypeScript that produced it.
 *
 * **Two independent derivations.** `packages/contract` builds the document;
 * this reads what was committed. A gate comparing the router to the *builder*
 * would go green on a change that never reached `contract/openapi.json`, which
 * is the artifact clients are handed.
 *
 * **Walked up rather than counted in `..` segments**, for the reason
 * `packages/core/test/authored-pack.ts` records: Stryker runs the suite from a
 * sandbox copy, so a fixed relative path lands nowhere — and a test whose
 * fixture cannot be read does not fail under Stryker, it simply covers nothing.
 */
function findContract(start: string): string {
  const relative = join("contract", "openapi.json");
  let directory = start;
  for (;;) {
    const candidate = join(directory, relative);
    if (existsSync(candidate)) {
      return candidate;
    }
    const parent = dirname(directory);
    if (parent === directory) {
      throw new Error(`${relative} not found above ${start}`);
    }
    directory = parent;
  }
}

export interface ContractedOperation {
  readonly method: string;
  readonly path: string;
  readonly operationId: string;
  readonly statuses: readonly string[];
}

interface JsonSchema {
  readonly required?: readonly string[];
  readonly additionalProperties?: boolean;
  readonly properties?: Record<string, { type?: string; enum?: readonly string[] }>;
  readonly $ref?: string;
}

interface Operation {
  readonly operationId: string;
  readonly responses: Record<string, unknown>;
  readonly requestBody?: {
    readonly content?: Record<string, { readonly schema?: JsonSchema }>;
  };
}

const document = JSON.parse(
  readFileSync(findContract(process.cwd()), "utf8"),
) as {
  paths: Record<string, Record<string, Operation>>;
  components: { schemas: Record<string, JsonSchema> };
};

/** Every operation the committed contract describes, method upper-cased. */
export const contractedOperations: readonly ContractedOperation[] = Object.entries(
  document.paths,
)
  .flatMap(([path, operations]) =>
    Object.entries(operations).map(([method, operation]) => ({
      method: method.toUpperCase(),
      path,
      operationId: operation.operationId,
      statuses: Object.keys(operation.responses),
    })),
  )
  .sort((a, b) => `${a.method} ${a.path}`.localeCompare(`${b.method} ${b.path}`));

/** The frozen `Error` schema, as JSON Schema. */
export const errorSchema = document.components.schemas["Error"] as {
  required: readonly string[];
  additionalProperties: boolean;
  properties: Record<string, { type: string }>;
};

/**
 * The request body an operation takes, with its `$ref` followed once.
 *
 * **Resolved from the path, not named.** A caller asking for `"PlayerLink"` by
 * name would go quietly green the day the schema is renamed and the operation
 * points somewhere else; asking `POST /players/link` what it accepts cannot.
 *
 * Throws rather than returning undefined: every use here is a gate, and a gate
 * that silently checks nothing is worse than no gate (PROC-10).
 */
export function requestBodyOf(method: string, path: string): JsonSchema {
  const operation = document.paths[path]?.[method.toLowerCase()];
  if (!operation) {
    throw new Error(`the contract describes no ${method} ${path}`);
  }
  const schema = operation.requestBody?.content?.["application/json"]?.schema;
  if (!schema) {
    throw new Error(`${method} ${path} declares no JSON request body`);
  }
  if (!schema.$ref) {
    return schema;
  }
  const name = schema.$ref.replace("#/components/schemas/", "");
  const resolved = document.components.schemas[name];
  if (!resolved) {
    throw new Error(`${method} ${path} refers to a schema named ${name}, which is absent`);
  }
  return resolved;
}

/**
 * Whether a body satisfies the frozen `Error` schema.
 *
 * Hand-checked against the artifact's own JSON Schema rather than against a
 * Zod type imported from `@akimath/contract`: the server's runtime dependency
 * list is `pg` and nothing else, and a gate is not a reason to grow it.
 */
export function validatesAsError(body: unknown): boolean {
  if (typeof body !== "object" || body === null || Array.isArray(body)) {
    return false;
  }
  const record = body as Record<string, unknown>;
  for (const key of errorSchema.required) {
    if (typeof record[key] !== errorSchema.properties[key]?.type) {
      return false;
    }
  }
  if (errorSchema.additionalProperties) {
    return true;
  }
  return Object.keys(record).every((key) => key in errorSchema.properties);
}
