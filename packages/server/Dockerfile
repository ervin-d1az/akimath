# The API image.
#
# **Three packages, one image.** `@akimath/core` and `@akimath/contract` are
# `file:` links, so a build from `packages/server/` alone cannot see them. The
# context is the repository root — that is where Fly puts it, since that is
# where `fly.toml` lives — so every path below is repo-relative, and
# `/.dockerignore` keeps the Flutter client, the plans and the emitted
# artifacts out of the tarball.
#
# **They are built, not stripped, and the repository is not changed to say so.**
# Both packages export TypeScript source, and that source imports with `.js`
# specifiers as NodeNext requires — which Node's type stripping does not
# rewrite. Measured: `node dist/src/main.js` against source exports fails with
# `Cannot find module …/core/src/rational.js`.
#
# The obvious fix is to point their `exports` at `dist` in the repository. It
# was tried and rejected on evidence: with no `dist` present, `npm test` in
# `packages/server` drops from 331 passing to 184 and eleven files fail to
# collect with `Failed to resolve entry for package "@akimath/contract"`. That
# makes the everyday gate depend on a prior build — a cost every session pays
# for this image's benefit alone. So the rewrite happens **here**, after the
# build and inside the image, where `dist` is guaranteed to exist.
FROM node:24-alpine AS build
WORKDIR /repo

# Manifests first, so editing source does not re-run the install.
COPY packages/contract/package.json packages/contract/package-lock.json ./contract/
COPY packages/core/package.json     packages/core/package-lock.json     ./core/
COPY packages/server/package.json   packages/server/package-lock.json   ./server/
RUN npm ci --prefix contract && npm ci --prefix core && npm ci --prefix server

COPY packages/contract ./contract
COPY packages/core     ./core
COPY packages/server   ./server
RUN npm run build --prefix contract \
 && npm run build --prefix core \
 && npm run build --prefix server

# The rewrite the header argues for. `npm pkg set` edits the manifest the
# runtime stage copies; resolution is read at import time, so this is all it
# takes. Verified before it was written here: both packages resolve, 32 and 41
# exports.
# **Not `npm pkg set`.** It reads dots as path separators, so `exports..types`
# writes a key that is not `"."` and Node then refuses the whole manifest:
# `"exports" cannot contain some keys starting with '.' and some not`. That
# failure is why the first deploy crash-looped. This rewrites the `"."` entry
# and leaves every subpath — core's `./pack/starter.json` among them — alone.
RUN node -e 'const fs=require("fs"); \
  for (const p of ["contract","core"]) { \
    const f=p+"/package.json", j=JSON.parse(fs.readFileSync(f)); \
    j.exports={...j.exports, ".":{types:"./dist/src/index.d.ts",default:"./dist/src/index.js"}}; \
    fs.writeFileSync(f, JSON.stringify(j,null,2)+"\n"); \
  }'

# **A runtime install, not a copy of the build's.** `npm ci --omit=dev` resolves
# a tree with no tsx, vitest, stryker or typescript in it — the image ships the
# four third-party runtime dependencies DEP-1 audits and nothing else.
FROM node:24-alpine AS runtime
WORKDIR /repo
ENV NODE_ENV=production

COPY --from=build /repo/contract/package.json /repo/contract/package-lock.json ./contract/
COPY --from=build /repo/core/package.json     /repo/core/package-lock.json     ./core/
COPY packages/server/package.json packages/server/package-lock.json ./server/
RUN npm ci --omit=dev --prefix contract \
 && npm ci --omit=dev --prefix core \
 && npm ci --omit=dev --prefix server

COPY --from=build /repo/contract/dist ./contract/dist
COPY --from=build /repo/core/dist     ./core/dist
COPY --from=build /repo/server/dist   ./server/dist
# The pack the server issues. `core`'s exports name it, and it is data rather
# than code, so it is not in `dist`.
COPY --from=build /repo/core/pack     ./core/pack

# Not root. The Alpine node image already ships an unprivileged `node` user.
USER node
WORKDIR /repo/server
EXPOSE 8080
CMD ["node", "dist/src/main.js"]
