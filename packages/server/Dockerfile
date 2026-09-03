# The API image.
#
# **Three packages, one image.** `@akimath/core` and `@akimath/contract` are
# `file:` links, so the build context is the repository's `packages/` directory
# rather than this one — a build from `packages/server/` alone cannot see them.
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
# makes the everyday gate depend on a prior build, which is a real cost paid by
# every session for the benefit of this image alone.
#
# So the rewrite happens **here**, after the build and inside the image, where
# `dist` is guaranteed to exist. The repository keeps source exports and its
# suites keep running with no build step.
FROM node:24-alpine AS build
WORKDIR /repo

# Manifests first, so a change to source does not re-run the install.
COPY contract/package.json contract/package-lock.json ./contract/
COPY core/package.json     core/package-lock.json     ./core/
COPY server/package.json   server/package-lock.json   ./server/
RUN npm ci --prefix contract && npm ci --prefix core && npm ci --prefix server

COPY contract ./contract
COPY core     ./core
COPY server   ./server
RUN npm run build --prefix contract \
 && npm run build --prefix core \
 && npm run build --prefix server

# The rewrite the header argues for. `npm pkg set` edits the manifest the
# runtime stage copies; resolution is read at import time, so this is all it
# takes. Verified locally before it was written here: both packages resolve,
# 32 and 41 exports.
RUN npm pkg set --prefix contract \
      'exports..types=./dist/src/index.d.ts' 'exports..default=./dist/src/index.js' \
 && npm pkg set --prefix core \
      'exports..types=./dist/src/index.d.ts' 'exports..default=./dist/src/index.js'

# **Runtime install, not a copy of the build's.** `npm ci --omit=dev` resolves a
# tree without tsx, vitest, stryker or typescript — the image ships the four
# third-party runtime dependencies DEP-1 audits and nothing else.
FROM node:24-alpine AS runtime
WORKDIR /repo
ENV NODE_ENV=production

COPY --from=build /repo/contract/package.json /repo/contract/package-lock.json ./contract/
COPY --from=build /repo/core/package.json     /repo/core/package-lock.json     ./core/
COPY server/package.json   server/package-lock.json   ./server/
RUN npm ci --omit=dev --prefix contract \
 && npm ci --omit=dev --prefix core \
 && npm ci --omit=dev --prefix server

COPY --from=build /repo/contract/dist ./contract/dist
COPY --from=build /repo/core/dist     ./core/dist
COPY --from=build /repo/server/dist   ./server/dist
# The pack the server issues. `core`'s exports name it, and it is data rather
# than code, so it is not in `dist`.
COPY --from=build /repo/core/pack     ./core/pack

# Not root. Alpine's node image already ships an unprivileged `node` user.
USER node
WORKDIR /repo/server
EXPOSE 8080
CMD ["node", "dist/src/main.js"]
