import { mkdirSync, readdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";

import { z } from "zod";

import { buildCanonGolden } from "../canon-vectors.js";
import { canonicalJson } from "../canonical-json.js";
import { PackSchema, parsePack, type PackResult } from "../pack.js";
import { PUZZLE_PAYLOAD_SCHEMAS } from "../puzzle/index.js";
import { STIMULUS_PAYLOAD_SCHEMAS } from "../stimulus/index.js";

/**
 * The one module in this package that touches the filesystem (design.md D9).
 * It holds no decision: what a schema is comes from `src/`, what canonical
 * bytes are comes from `canonical-json.ts`, and this walks directories and
 * writes what it was handed.
 */
export interface EmitOptions {
  readonly sourceRoot: string;
  readonly outputRoot: string;
}

const GROUPS = ["stimulus", "puzzle", "diagnosis"] as const;

function schemaMap(schemas: Readonly<Record<string, z.ZodType>>): Record<string, unknown> {
  return Object.fromEntries(
    Object.entries(schemas).map(([kind, schema]) => [kind, z.toJSONSchema(schema)]),
  );
}

function write(path: string, value: unknown): void {
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, canonicalJson(value), "utf8");
}

function goldenNames(directory: string): readonly string[] {
  return readdirSync(directory)
    .filter((name) => name.split(".").length === 2 && name.endsWith(".json"))
    .sort();
}

function normalisedOf(fixturePath: string): unknown {
  const parsed: PackResult = parsePack(JSON.parse(readFileSync(fixturePath, "utf8")));
  return parsed.ok ? { ok: true, pack: parsed.pack } : { ok: false, tag: parsed.tag };
}

/**
 * `f1b-content-reader` compares its Dart parser against the structure written
 * beside each fixture, so the record has to be produced by the parser rather
 * than transcribed by hand (design.md D6).
 */
function emitNormalisedRecords(options: EmitOptions): void {
  for (const group of GROUPS) {
    const source: string = join(options.sourceRoot, "fixtures", group);
    for (const name of goldenNames(source)) {
      const stem: string = name.replace(/\.json$/u, "");
      write(
        join(options.outputRoot, "fixtures", group, `${stem}.normalised.json`),
        normalisedOf(join(source, name)),
      );
    }
  }
}

export function emitContract(options: EmitOptions): void {
  write(join(options.outputRoot, "pack.schema.json"), z.toJSONSchema(PackSchema));
  write(join(options.outputRoot, "stimulus.schema.json"), schemaMap(STIMULUS_PAYLOAD_SCHEMAS));
  write(join(options.outputRoot, "puzzle.schema.json"), schemaMap(PUZZLE_PAYLOAD_SCHEMAS));
  write(join(options.outputRoot, "fixtures", "canon.golden.json"), buildCanonGolden());
  emitNormalisedRecords(options);
}

function repositoryContractRoot(): string {
  return join(import.meta.dirname, "..", "..", "..", "..", "contract");
}

if (process.argv[1] === import.meta.filename) {
  const root: string = repositoryContractRoot();
  emitContract({ sourceRoot: root, outputRoot: root });
}
