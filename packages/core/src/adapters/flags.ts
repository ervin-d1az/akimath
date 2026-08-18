/**
 * Command-line flags, for the adapters that take them.
 *
 * **Shared because it is one behaviour, not two.** `build-pack.ts` and
 * `build-puzzles.ts` both read `--name value` off `process.argv`, and two
 * copies of that parse would be two chances to disagree about what `--out`
 * means. Unlike the template versions next door, there is no frozen-history
 * argument for duplicating it.
 */
export function flag(name: string, fallback: string): string {
  const at = process.argv.indexOf(`--${name}`);
  const value = at === -1 ? undefined : process.argv[at + 1];
  return value === undefined ? fallback : value;
}
