/**
 * One spelling of a JSON value, so the committed artifacts are a function of
 * their content and not of the order a schema library happened to build them
 * in. Sorting is a decision, so it lives here on the pure side and the emitter
 * in `src/adapters/` only writes what this returns (design.md D9).
 */
const INDENT = 2;

function sortKeys(value: unknown): unknown {
  if (Array.isArray(value)) {
    return value.map(sortKeys);
  }
  if (value === null || typeof value !== "object") {
    return value;
  }
  const entries: [string, unknown][] = Object.entries(value as Record<string, unknown>)
    .map(([key, nested]): [string, unknown] => [key, sortKeys(nested)])
    .sort(([left], [right]) => (left < right ? -1 : 1));
  return Object.fromEntries(entries);
}

export function canonicalJson(value: unknown): string {
  return `${JSON.stringify(sortKeys(value), null, INDENT)}\n`;
}
