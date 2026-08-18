import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import ts from "typescript";
import { describe, expect, it } from "vitest";

/**
 * **Nothing reachable from the public surface imports a package.**
 *
 * `src/index.ts`'s own header claims zero runtime dependencies, and
 * `dependency-allowlist.test.ts` checks that by reading the manifest. That was
 * enough while the manifest was the whole story. It stops being enough the
 * moment a *dev* dependency exists that the source could import — F1.5 adds a
 * pack builder that needs `@akimath/contract`, and a devDependency is on disk
 * at test time exactly like a runtime one. Nothing would have failed.
 *
 * So the claim is checked where it actually lives: walk the imports reachable
 * from the entry point and assert none of them leaves the package. The builder
 * may import contract all it likes, because the builder is not reachable from
 * `index.ts` — and this is the test that keeps that true.
 */

/** One import that leaves the package. */
interface Escape {
  readonly file: string;
  readonly line: number;
  readonly specifier: string;
}

interface Walk {
  readonly visited: readonly string[];
  readonly escapes: readonly Escape[];
}

/**
 * Every module reachable from [entry], and every non-relative specifier they
 * import between them.
 *
 * **PURE** — [read] is injected, so the control below can walk a tree that does
 * not exist on disk rather than committing a violation to prove the walker
 * works.
 *
 * `node:` builtins are not escapes: they ship with the runtime and are not
 * something a manifest can pin or a supply chain can compromise. Anything else
 * bare — `zod`, `@akimath/contract` — is a package, and a package is the thing
 * this is looking for.
 */
export function walkImports(
  entry: string,
  read: (file: string) => string | null,
): Walk {
  const visited: string[] = [];
  const escapes: Escape[] = [];
  const queue: string[] = [entry];

  while (queue.length > 0) {
    const file = queue.shift() as string;
    if (visited.includes(file)) {
      continue;
    }
    const text = read(file);
    if (text === null) {
      continue;
    }
    visited.push(file);

    const source = ts.createSourceFile(file, text, ts.ScriptTarget.ES2023, true);
    const record = (specifier: string, node: ts.Node): void => {
      if (specifier.startsWith("node:")) {
        return;
      }
      if (!specifier.startsWith(".")) {
        escapes.push({
          file: path.basename(file),
          line:
            source.getLineAndCharacterOfPosition(node.getStart(source)).line + 1,
          specifier,
        });
        return;
      }
      // `./rational.js` on disk is `./rational.ts` — NodeNext spells the
      // emitted name, and this walks the source.
      const resolved = path.resolve(
        path.dirname(file),
        specifier.replace(/\.js$/u, ".ts"),
      );
      queue.push(resolved);
    };

    ts.forEachChild(source, function visit(node: ts.Node): void {
      if (
        (ts.isImportDeclaration(node) || ts.isExportDeclaration(node)) &&
        node.moduleSpecifier !== undefined &&
        ts.isStringLiteral(node.moduleSpecifier)
      ) {
        record(node.moduleSpecifier.text, node.moduleSpecifier);
      }
      ts.forEachChild(node, visit);
    });
  }

  return { visited, escapes };
}

const ENTRY = fileURLToPath(new URL("../src/index.ts", import.meta.url));

describe("the public surface imports no package", () => {
  const walk = walkImports(ENTRY, (file) => {
    try {
      return readFileSync(file, "utf8");
    } catch {
      return null;
    }
  });

  it("walked a real tree", () => {
    // PROC-10. A mistyped entry point walks one file and finds nothing, which
    // looks exactly like a clean surface.
    expect(walk.visited.length).toBeGreaterThan(1);
    // eslint-disable-next-line no-console
    console.log(
      `  import boundary · ${walk.visited.length} modules reachable from index.ts`,
    );
  });

  it("nothing reachable from index.ts leaves the package", () => {
    expect(
      walk.escapes.map((e) => `${e.file}:${e.line} imports ${e.specifier}`),
      "the exported surface reached for a package",
    ).toEqual([]);
  });
});

describe("the walker sees a violation that is there", () => {
  // The control. Every assertion above passes for a walker that is simply
  // broken, and this tells the two apart without committing a violation.
  const sources: Record<string, string> = {
    "/x/index.ts": 'export { a } from "./a.js";\n',
    "/x/a.ts": 'import { answerDigest } from "@akimath/contract";\nexport const a = answerDigest;\n',
  };
  const walk = walkImports("/x/index.ts", (f) => sources[f] ?? null);

  it("follows a relative re-export into the module it names", () => {
    expect(walk.visited).toEqual(["/x/index.ts", "/x/a.ts"]);
  });

  it("reports the package, the file and the line", () => {
    expect(walk.escapes).toEqual([
      { file: "a.ts", line: 1, specifier: "@akimath/contract" },
    ]);
  });

  it("does not report a node builtin", () => {
    const only = { "/y/index.ts": 'import { readFileSync } from "node:fs";\nexport const r = readFileSync;\n' };
    expect(walkImports("/y/index.ts", (f) => only[f as keyof typeof only] ?? null).escapes).toEqual([]);
  });
});
