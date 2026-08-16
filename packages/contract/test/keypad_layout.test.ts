import { describe, expect, it } from "vitest";

import { KEYPAD_LAYOUTS, KeypadLayoutSchema } from "../src/keypad-layout.js";

describe("KeypadLayout", () => {
  it("closes at the three layouts the design draws", () => {
    expect(KEYPAD_LAYOUTS).toEqual(["item", "puzzle", "otp"]);
  });

  it("accepts each of the three layouts", () => {
    for (const layout of KEYPAD_LAYOUTS) {
      expect(KeypadLayoutSchema.safeParse(layout).success).toBe(true);
    }
  });

  it("rejects a fourth layout name", () => {
    expect(KeypadLayoutSchema.safeParse("scientific").success).toBe(false);
  });

  it("rejects a per-key list", () => {
    expect(KeypadLayoutSchema.safeParse(["1", "2", "3", "⌫"]).success).toBe(false);
  });

  it("rejects a bespoke keypad object", () => {
    expect(KeypadLayoutSchema.safeParse({ rows: 4, columns: 4 }).success).toBe(false);
  });
});
