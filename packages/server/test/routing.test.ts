import { describe, expect, it } from "vitest";

import { route } from "../src/routing.js";

describe("route", () => {
  it("reports health for GET /health", () => {
    expect(route("GET", "/health", "1.2.3")).toEqual({
      status: 200,
      body: { status: "ok", service: "akimath-api", version: "1.2.3" },
    });
  });

  it("refuses a non-GET method on /health", () => {
    expect(route("POST", "/health", "1.2.3").status).toBe(404);
  });

  it("reports not found for an unknown path", () => {
    expect(route("GET", "/nope", "1.2.3")).toEqual({
      status: 404,
      body: { error: "not_found" },
    });
  });
});
