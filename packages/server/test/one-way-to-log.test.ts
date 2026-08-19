import { readdirSync, readFileSync, statSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { join } from "node:path";
import { describe, expect, it } from "vitest";

const SRC = fileURLToPath(new URL("../src", import.meta.url));

/**
 * The one file allowed to touch a stream, named rather than matched.
 *
 * A pattern — "anything under adapters/" — would excuse the next file that
 * quietly starts printing, which is the whole failure this gate exists to
 * prevent.
 */
const THE_WRITER = "adapters/logger.ts";

function sourcesUnder(directory: string, prefix = ""): readonly string[] {
  return readdirSync(directory).flatMap((entry) => {
    const path = join(directory, entry);
    const relative = prefix === "" ? entry : `${prefix}/${entry}`;
    if (statSync(path).isDirectory()) {
      return sourcesUnder(path, relative);
    }
    return entry.endsWith(".ts") ? [relative] : [];
  });
}

describe("there is one way to write a log line", () => {
  const sources = sourcesUnder(SRC);

  it("reports what it scanned, and scanning nothing is a failure", () => {
    // PROC-10. A gate whose input set can silently reach zero cannot tell
    // "nothing is wrong" from "nothing was checked" — and this one resolves its
    // root from `import.meta.url`, which Stryker's sandbox copy relocates.
    expect(sources.length).toBeGreaterThan(0);
    console.log(`  one way to log · scanned ${sources.length} source file(s)`);
  });

  it("the writer is one named file, not a directory", () => {
    expect(sources).toContain(THE_WRITER);
  });

  it("nothing else calls console, and nothing else writes to a stream", () => {
    // Two prohibitions, because they fail differently. `console.*` is the habit;
    // `process.stdout.write` is what somebody reaches for after being told not
    // to use `console`.
    const offenders = sources
      .filter((relative) => relative !== THE_WRITER)
      .flatMap((relative) => {
        const source = readFileSync(join(SRC, relative), "utf8");
        return [
          ...(/\bconsole\s*\./.test(source) ? [`${relative} calls console`] : []),
          ...(/\bprocess\.(stdout|stderr)\b/.test(source)
            ? [`${relative} writes to a stream directly`]
            : []),
        ];
      });

    expect(offenders).toEqual([]);
  });
});
