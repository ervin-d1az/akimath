import { describe, expect, it } from "vitest";

import { erasureResponse } from "../src/erasure.js";
import { validatesAsError } from "./support/contract.js";

describe("what DELETE /me answers", () => {
  it("204 with no body when a player was erased", () => {
    const response = erasureResponse(true);

    expect(response).toEqual({ status: 204 });
    // The absence is the assertion. A 204 that carries a body is a `TypeError`
    // in the Fetch `Response` constructor, so "no `body` key" is what the
    // adapter branches on — `toEqual` above already fails on an extra key, and
    // this says why out loud.
    expect("body" in response).toBe(false);
  });

  it("404 in the frozen Error shape when the account never had one", () => {
    const response = erasureResponse(false);

    expect(response.status).toBe(404);
    expect("body" in response && validatesAsError(response.body)).toBe(true);
    expect("body" in response && response.body).toEqual({
      error: "no_player",
      message: "This account has no player, so there is nothing to erase.",
    });
  });

  it("and it does not send someone who asked to be forgotten off to link", () => {
    // `profileResponse`'s 404 says "Link one with POST /players/link", which is
    // the right advice for `GET /me` and the wrong one here. Asserted rather
    // than left to the eye, because reusing that function is the obvious
    // shortcut and it compiles.
    const response = erasureResponse(false);

    expect("body" in response && JSON.stringify(response.body)).not.toContain("link");
  });
});
