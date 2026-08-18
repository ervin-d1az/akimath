import { writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

import { buildTemplateGolden } from "../golden.js";
import { buildPrngGolden } from "../prng/golden.js";
import { buildRatingGolden } from "../rating/golden.js";

/**
 * The **only** filesystem writer in this package, and it holds no decision.
 *
 * It calls the three builders and serialises what they return. Everything about
 * *what* goes in an artifact lives in the pure module beside the thing it
 * describes, so the whole package stays testable without a disk.
 */
const ARTIFACTS = [
  ["prng.golden.json", buildPrngGolden],
  ["templates.golden.json", buildTemplateGolden],
  ["rating.golden.json", buildRatingGolden],
] as const;

for (const [name, build] of ARTIFACTS) {
  const path = fileURLToPath(new URL(`../../golden/${name}`, import.meta.url));
  writeFileSync(path, `${JSON.stringify(build(), null, 2)}\n`, "utf8");
  console.log(`wrote golden/${name}`);
}
