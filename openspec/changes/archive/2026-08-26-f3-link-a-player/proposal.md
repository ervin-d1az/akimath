# A player can be linked to an account

## Why

The endpoint the whole account flow was for. An account could be created and
verified and still had no player — which is exactly what the app has been saying
on screen, in as many words, since the states landed.

## What changes

- **`POST /players/link`**, and `linkPlayer` joins `IMPLEMENTED_OPERATIONS`, so
  the contract's 501 list prunes itself to six.
- **409** on the contract for the two ways a second link is refused. oasdiff
  calls it info, not breaking.
- The handler seam widens from a user id to the whole request, because this one
  needs a body and a header.
- **`ApiClient.linkPlayer`** on the Dart side, with its own sealed result.

## Out of scope

An idempotency store. The operation is idempotent *by nature* — the inputs
determine the row — so the required header needs nothing behind it yet. Written
down rather than left as an omission.
