# 2. Neon Auth holds accounts, and nothing syncs until one exists

**Status:** Accepted — 2026-08-19, decided from the `akimath` Neon project's own configuration.

---

## Context

`ARCHITECTURE.md` §5 specified the identity model in one sentence:

> **Identity: `players` is the game identity; Better Auth's `anonymous()` only supplies a
> session.**

and set two conditions on the auth provider: a **floor of Better Auth `>= 1.6.22`** for
GHSA-qq9h-g4jm-xgf3, and `advanced.ipAddress.disableIpTracking: true`, because by default Better
Auth "persists IP and user-agent **of minors**".

The provider was then chosen: **Neon Auth**, which is managed Better Auth hosted by Neon, storing
identity in a `neon_auth` schema inside the project's own Postgres and exposing a REST API. That
choice is good on its own terms — it removes a deployment target, keeps the app free of any
third-party SDK, and puts identity in a database we already own.

But it cannot satisfy §5 as written, and the reasons were read off the running project rather
than inferred:

1. **There is no anonymous plugin.** The console's Plugins tab offers exactly three —
   Organizations, Magic Link, Phone Authentication — and `neon_auth.project_config.plugin_configs`
   lists the same three and nothing else. Better Auth's `anonymous()` is not exposed.
2. **IP tracking is not configurable.** `project_config` has twelve columns and none is an
   `advanced` block; the Configuration tab offers no such control. Meanwhile
   `neon_auth.session` carries `ipAddress` and `userAgent` columns.
3. **The version is 1.4.18**, inside GHSA-qq9h-g4jm-xgf3's affected range (1.1.3 → 1.6.22), and a
   managed service cannot be patched by us.

Taken together: every Neon session belongs to a real account, and every session records an IP.
There is no configuration of Neon Auth in which a child playing offline has no row.

## Decision

**Neon Auth authenticates accounts. It never touches a child's device.**

- **Unlinked play is entirely offline.** The client mints `player_id` as a UUIDv7 on first launch
  and keeps everything on the device. No Neon session, no row in any table, no IP recorded.
  §5's "zero rows in the database until first sync" becomes **zero rows, full stop**, for as long
  as nobody links.
- **Linking is the first server contact, and it is an adult's act.** Creating an account is what
  makes sync possible; there is no earlier moment at which data could leave the device.
- **Sync and account are one event**, not two. An unlinked device does not sync — not "syncs
  later", not "syncs anonymously".

The alternative was a credential an unlinked device could present. Neon Auth will not issue one,
and `CLAUDE.md` forbids the obvious substitute outright — *"Never hand-write authentication
crypto"*. A second auth mechanism running beside the managed one, written by us, guarding
children's data, is the worst option on the table and was not close.

## Consequences

**What this buys.** For every player who never links, there is nothing to leak, nothing to
delete, and nothing to explain: the IP-tracking problem does not need solving because no session
exists. That is a stronger position than the one §5 was aiming at, and it is reached by removing
a component rather than configuring one.

**What it costs.**

- **No cross-device resume for unlinked players.** §5 had already conceded this — *"v1 is one
  device per child"* — so the ground was given up before this decision, not by it.
- **Rating only applies to linked accounts.** F4's adaptive difficulty is server-side by rule
  (*"Rating never runs in Dart"*), so an unlinked player stays on the pack's `ladder_step`
  forever. This is the real product consequence and it belongs in F4's proposal, not buried here.
- **Erasure splits in two.** For an unlinked player, `DELETE /v1/me` has nothing to erase; the
  data is on their device and uninstalling removes it. For a linked one, the erasure path must
  clear `neon_auth` rows through the provider's API and not only our own tables.

**What follows immediately.** `packages/server` still has no framework, and Neon Auth's REST API
has to be reached from somewhere; `ARCHITECTURE.md` §5 already names Hono. That is the next
change, and it lands on its own so the dependency audit is not mixed with an auth review.

## Evidence

The GHSA preconditions were closed in the console on 2026-08-19 and confirmed against the
database rather than the screenshot:

```
$ psql "$MIGRATE_DATABASE_URL" -At -c \
    "select email_and_password::text from neon_auth.project_config;"
{"enabled": false, "disableSignUp": true, ...}

$ psql "$MIGRATE_DATABASE_URL" -At -c \
    "select jsonb_pretty(plugin_configs) from neon_auth.project_config;"
magicLink   → "enabled": false
phoneNumber → "enabled": false
organization → "enabled": true
```

The advisory needs magic-link **or** email-OTP **and** open email+password registration. With
email+password disabled entirely and magic-link off, no path remains — the version is still
1.4.18 and the exploit has nowhere to start.

The absence of the anonymous plugin was read twice, from the console's Plugins tab and from
`plugin_configs`, because a single source would have left "the console does not show it" and "it
does not exist" indistinguishable.

`neon_auth.session` was inspected for its columns and never its rows; `user` and `session` were
both empty at the time of writing (`select count(*)` — 0 and 0).

## Open

- **Organizations is still enabled** (`membershipLimit: 100`, invitations). It is unused, it adds
  three tables, and it should be off.
- **Allow Localhost is on**, which Neon's own help text limits to local development. It must be
  off before release.
- **Google OAuth uses Neon's shared keys**, so the consent screen is Neon's rather than ours.
  That is tolerable while nothing ships and is not tolerable at launch.
- **The IP question returns the moment an adult links**, for that adult. It is a smaller problem
  than the one this ADR removes — an adult who creates an account is not a minor whose IP was
  taken without a decision — but it is not nothing, and Neon should be asked whether
  `disableIpTracking` can be exposed.
