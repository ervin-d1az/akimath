import { describe, expect, it } from "vitest";

import { standingResponse, type SkillRating } from "../src/standing.js";
import { schemaNamed } from "./support/contract.js";

const PLAYER = "018f4e3c-0000-7000-8000-0000000000b1";
const AT = new Date("2026-08-19T09:15:00.000Z");

const rated = (over: Partial<SkillRating> = {}): SkillRating => ({
  skillId: 1,
  rating: 1200.5,
  deviation: 350,
  updatedAt: AT,
  ...over,
});

/** The frozen shape of one entry in `Standing.skills`, read rather than restated. */
const skillSchema = (): { required: string[]; properties: Record<string, unknown> } => {
  const standing = schemaNamed("Standing") as {
    properties: {
      skills: { items: { required: string[]; properties: Record<string, unknown> } };
    };
  };
  return standing.properties.skills.items;
};

describe("the standing a player is answered with", () => {
  it("is the frozen Standing, one entry per rated skill", () => {
    const response = standingResponse(PLAYER, [rated()]);

    expect(response.status).toBe(200);
    expect(response.body).toEqual({
      playerId: PLAYER,
      skills: [
        {
          skillId: 1,
          rating: 1200.5,
          deviation: 350,
          updatedAt: "2026-08-19T09:15:00.000Z",
        },
      ],
    });
  });

  it("carries every field the schema requires and none it does not", () => {
    const { skills } = standingResponse(PLAYER, [rated()]).body as {
      skills: Record<string, unknown>[];
    };
    const schema = skillSchema();

    expect(schema.required.length).toBeGreaterThan(0);
    expect(Object.keys(skills[0]!).sort()).toEqual([...schema.required].sort());
    expect(Object.keys(skills[0]!).sort()).toEqual(Object.keys(schema.properties).sort());
  });

  it("and the answer itself carries exactly the two fields Standing names", () => {
    const standing = schemaNamed("Standing") as {
      required: string[];
      properties: Record<string, unknown>;
    };
    const body = standingResponse(PLAYER, []).body as Record<string, unknown>;

    expect(Object.keys(body).sort()).toEqual([...standing.required].sort());
    expect(Object.keys(body).sort()).toEqual(Object.keys(standing.properties).sort());
  });

  it("a player nothing has rated yet gets an empty list, not a 404", () => {
    // **The empty array is the absence.** `rating` is required and *not*
    // nullable in the frozen schema, so there is no `null` to answer with the
    // way `GET /me/history` answers a null `ratingDelta` — a skill with no
    // rating is a skill with no entry. Rating is F4 and nothing writes
    // `user_skills`, so this is every player today, and it is the honest shape
    // rather than an invented number.
    expect(standingResponse(PLAYER, [])).toEqual({
      status: 200,
      body: { playerId: PLAYER, skills: [] },
    });
  });

  it("the instant carries milliseconds and a Z, which the schema pins", () => {
    // The frozen `date-time` pattern requires both, and `toISOString` is the one
    // `Date` method that produces exactly it — the same rule `profileResponse`
    // keeps next to `createdAt`.
    const pattern = new RegExp(
      (skillSchema().properties as { updatedAt: { pattern: string } }).updatedAt.pattern,
    );
    const { skills } = standingResponse(PLAYER, [rated()]).body as {
      skills: { updatedAt: string }[];
    };

    expect(skills[0]!.updatedAt).toMatch(pattern);
  });

  it("every rated skill is answered, in the order the repository gave them", () => {
    // Ordering is the query's, the way `GET /me/history` orders its sessions.
    // Re-sorting here would be a second opinion about it.
    const { skills } = standingResponse(PLAYER, [
      rated({ skillId: 4, rating: 900 }),
      rated({ skillId: 1, rating: 1200.5 }),
    ]).body as { skills: { skillId: number }[] };

    expect(skills.map((skill) => skill.skillId)).toEqual([4, 1]);
  });

  it("the player it names is the one asked about", () => {
    const other = "018f4e3c-0000-7000-8000-0000000000b2";
    expect((standingResponse(other, []).body as { playerId: string }).playerId).toBe(other);
  });
});
