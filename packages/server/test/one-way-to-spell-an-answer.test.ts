import { readdirSync, readFileSync, statSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import ts from "typescript";
import { describe, expect, it } from "vitest";

/**
 * There is one way to decide how an exact answer is written down.
 *
 * The sibling of `packages/core/test/one-way-to-spell-an-answer.test.ts`, and
 * it exists here for a reason that is not symmetry: **this package held one of
 * the three implementations.** `gradeAnswer` wrote `storedAnswer(n, d).canonical`
 * out longhand, under a comment pointing at `packages/core`'s `build.ts` and
 * saying it had learned this the hard way — so the two agreed by coincidence of
 * two matching edits rather than by construction, which is the precondition for
 * bug #50 and not a description of the fix for it.
 *
 * A grading path is the worst place for that copy. #50 was latent because the
 * app ships an authored pack; a divergence here marks a right answer wrong for
 * a player who typed it correctly, and the batch is graded server-side where
 * nobody sees the arithmetic.
 *
 * Each package gets its own gate rather than one shared one, because each suite
 * has to be able to go red on its own regression — and because a package cannot
 * scan a sibling it does not depend on.
 *
 * **What it cannot see, stated rather than left to be discovered.** It reads
 * syntax, so a copy that names neither word nor the function — `ANSWER_SHAPES[
 * hasSlash ? 1 : 0]`, or a shape arriving through a helper in a third file —
 * walks past it. It catches the copy somebody writes without meaning to, which
 * is every copy this repository has actually grown, and it is not a proof.
 */

/**
 * The two members of `ANSWER_SHAPES`. **A copy has to name both**: deciding a
 * shape means choosing between them. Nothing under `src/` names either today,
 * which is what makes an empty allowlist below honest rather than lucky.
 */
const SHAPE_WORDS = ["integer", "fraction"] as const;

/**
 * The sharp ingredient, and the one this package actually reached for.
 * `renderCanonicalAnswer` spells a number and takes no view on the shape beside
 * it; `storedAnswer` and `storedAnswerOf` return the pair, which is the whole
 * point of their existing.
 */
const THE_SPELLER = "renderCanonicalAnswer";

/**
 * Empty, and stated rather than omitted. `packages/core` names one file here —
 * its distractor renderer, which spells a *wrong* answer that has no shape
 * beside it. Nothing on a request path has that excuse: everything this package
 * spells is an answer it is about to compare a player's typing against.
 */
const MAY_SPELL_BY_HAND: readonly string[] = [];

const SRC = fileURLToPath(new URL("../src", import.meta.url));

function sourceFiles(directory: string): string[] {
  return readdirSync(directory).flatMap((entry) => {
    const full = path.join(directory, entry);
    if (statSync(full).isDirectory()) return sourceFiles(full);
    return full.endsWith(".ts") ? [full] : [];
  });
}

interface Sighting {
  readonly file: string;
  readonly line: number;
  readonly what: string;
}

/**
 * An AST walk and not a regex, for one reason that bites here specifically:
 * this gate reads for two words that appear in *explanations* of the rule as
 * often as in code, and a syntax tree cannot see a comment at all.
 */
function scan(file: string): Sighting[] {
  const source = ts.createSourceFile(
    file,
    readFileSync(file, "utf8"),
    ts.ScriptTarget.ES2023,
    true,
  );
  const relative = path.relative(SRC, file).split(path.sep).join("/");
  const at = (node: ts.Node): number =>
    source.getLineAndCharacterOfPosition(node.getStart(source)).line + 1;

  const wordLines = new Map<string, number>();
  const sightings: Sighting[] = [];

  const visit = (node: ts.Node): void => {
    if (ts.isStringLiteral(node) && (SHAPE_WORDS as readonly string[]).includes(node.text)) {
      if (!wordLines.has(node.text)) wordLines.set(node.text, at(node));
    }
    if (
      ts.isCallExpression(node) &&
      ts.isIdentifier(node.expression) &&
      node.expression.text === THE_SPELLER &&
      !MAY_SPELL_BY_HAND.includes(relative)
    ) {
      sightings.push({ file: relative, line: at(node), what: `calls ${THE_SPELLER}` });
    }
    ts.forEachChild(node, visit);
  };
  visit(source);

  // Every shape word's line, because the *pair* is the violation and naming one
  // half of it points a reader at whichever came first, which need not be the
  // offending line at all.
  if (wordLines.size === SHAPE_WORDS.length) {
    const where = [...wordLines].map(([word, line]) => `${word}@${line}`).join(", ");
    sightings.push({
      file: relative,
      line: Math.min(...wordLines.values()),
      what: `decides an answer shape by hand (${where})`,
    });
  }
  return sightings;
}

describe("there is one way to spell a stored answer", () => {
  const files = sourceFiles(SRC);

  it("reports what it scanned, and scanning nothing is a failure", () => {
    // PROC-10. This gate resolves its root from `import.meta.url`, which
    // Stryker's sandbox relocates, and a walk over zero files is green.
    expect(files.length).toBeGreaterThan(0);
    console.log(`  one way to spell an answer · scanned ${files.length} source file(s)`);
  });

  it("nothing decides a shape by hand, and nothing spells one", () => {
    const sightings = files.flatMap(scan);
    expect(
      sightings.map((s) => `${s.file}:${s.line} ${s.what}`),
      "a second implementation of shape-and-spelling; call storedAnswer or storedAnswerOf",
    ).toEqual([]);
  });

  it("sees both violations when they are there", () => {
    // The control. Every assertion above passes for a walker that finds
    // nothing because it is broken, and the two are indistinguishable without
    // this. Both prohibitions, because they are found by different code.
    const probe = ts.createSourceFile(
      "probe.ts",
      [
        'const shape = answer.includes("/") ? "fraction" : "integer";',
        "const spelled = renderCanonicalAnswer(numerator, denominator);",
      ].join("\n"),
      ts.ScriptTarget.ES2023,
      true,
    );
    const words = new Set<string>();
    let spells = false;
    const visit = (node: ts.Node): void => {
      if (ts.isStringLiteral(node) && (SHAPE_WORDS as readonly string[]).includes(node.text)) {
        words.add(node.text);
      }
      if (
        ts.isCallExpression(node) &&
        ts.isIdentifier(node.expression) &&
        node.expression.text === THE_SPELLER
      ) {
        spells = true;
      }
      ts.forEachChild(node, visit);
    };
    visit(probe);

    expect([...words].sort()).toEqual([...SHAPE_WORDS].sort());
    expect(spells).toBe(true);
  });
});
