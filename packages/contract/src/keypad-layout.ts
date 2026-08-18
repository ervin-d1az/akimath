import { z } from "zod";

/**
 * The three keypads the design draws — item 4×4, puzzle 5×2, OTP 3×4 (plan
 * §5.3 D14). A template picks one by name; nothing anywhere declares a key
 * list, which is what keeps one key widget rendering every layout.
 *
 * `otp` has no consumer in this change and closes the enum anyway: reopening
 * a frozen enum is the failure this format exists to prevent, and D14 already
 * counted the layouts.
 */
export const KEYPAD_LAYOUTS = ["item", "puzzle", "otp"] as const;

export type KeypadLayout = (typeof KEYPAD_LAYOUTS)[number];

export const KeypadLayoutSchema = z.enum(KEYPAD_LAYOUTS);
