## 1. The scheme

- [x] 1.1 Red: the document declares no way to authenticate.
- [x] 1.2 `securitySchemes.session` — `http` / `bearer` / `JWT`, described from Neon's own
      documentation.
- [x] 1.3 Root `security`, and a sweep proving no operation overrides it.

## 2. The gate

- [x] 2.1 Every operation the contract secures is refused by `route()`; the ops route answers.
- [x] 2.2 Counts reported, and the gate shown to bite.

## 3. Evidence

- [x] 3.1 Tier 1 in both packages with counts; emit deterministic; oasdiff verdict recorded.
