# Template versions are duplicated on purpose

`src/templates/**` is excluded from the duplication gate in `.jscpd.json`, and
this file is the reason.

A template version is **frozen history**. An attempt recorded against `v1` in
2026 has to rederive as `v1` in 2029, so a revision adds `v2.ts` and never edits
`v1.ts`. Two versions of one template are therefore near-identical by
construction, and jscpd is right that they are duplicates — it is the *rule* that
is unusual, not the code.

Factoring the shared body into a helper both versions call would give them one
implementation, which is exactly what a version number exists to prevent:
changing the helper would silently change what every already-issued item
rederives to. The duplication is the safety property.

**The exclusion is this directory only.** The rest of `packages/core` is held to
the same zero-clone bar as `packages/server` and `packages/contract`, so a
copy-paste anywhere else still fails the gate.
