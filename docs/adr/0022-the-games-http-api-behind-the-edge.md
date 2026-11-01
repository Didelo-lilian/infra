# 22. The game's HTTP API behind the edge

Date: 2026-11-01 · Status: accepted · Amends [ADR 0015](0015-the-game-behind-the-edge.md); amended the same day for the sign-in

## Context

The backend of the game gets a first HTTP endpoint, `/api/me`, for the guest session ([ADR 0010 of semaphore](https://github.com/Didelo-lilian/semaphore/blob/main/docs/adr/0010-guest-sessions-in-valkey.md)): a pseudo and a session that outlive a room, which sign-in will build on. [ADR 0015](0015-the-game-behind-the-edge.md) sends only `/ws` to the backend and the rest of `play.didelo.fr` to the front's nginx, which would answer `/api/me` with the page.

`PUT /api/me` writes a hash (about 830 bytes, kept 7 days without use) in the Valkey that also holds the rooms, with 64 MB and `noeviction` ([ADR 0018](0018-redis-for-the-games-rooms.md)), for every browser that has no session yet. The entry point lets an address through at 30 requests a second: that is 25 KB a second, 64 MB in 43 minutes from one address.

## Decision

- **A router for `/api/`**, `Host(...) && PathPrefix('/api/')`, priority 100 on the same service. The trailing slash is deliberate: `/api` and `/apix` stay with the front, and nothing of the backend is reachable but what is under `/api/`. The actuator still is not.
- **A router of its own for `PUT /api/me`**, priority 110 so that it wins over the previous one, with two middlewares:
  - **`semaphore-guest-limit`: 60 requests an hour per IP, burst 30.** A person chooses a pseudo once, and a household or a class behind one address does it together, hence the burst of 30. After it an address gets one every minute: at most 10 080 sessions a week, 8 MB, an eighth of the Valkey, for an address that never stops. The criterion is the connection's address (`ipStrategy.depth: 0`), as for the other limits. A refused `PUT` is not a lockout: the front asks for the name in each room, as before guests.
  - **`semaphore-guest-body`: 1 KiB at most.** The body is `{"name": "…"}` with 20 characters, a few dozen bytes. Traefik answers 413 before the backend reads anything.
  `GET` and `DELETE` keep the entry point's limits alone: they create nothing.
- **A router of its own for `/api/auth`** (`Path('/api/auth') || PathPrefix('/api/auth/')`), priority 110, for the sign-in of [ADR 0011 of semaphore](https://github.com/Didelo-lilian/semaphore/blob/main/docs/adr/0011-sign-in-with-github-or-google.md). The start of a login keeps a key of about 700 bytes for 10 minutes in the same Valkey, and each callback asks the provider for a token, so every method is limited:
  - **`semaphore-auth-limit`: 120 requests an hour per IP, burst 40.** A login is two requests, the start and the callback, so the burst is 20 logins at once (a class behind one address), and then one a minute. At most 20 keys of 700 bytes wait in Valkey for one address. A request refused in the middle of a login ends on Traefik's 429 and the player tries again later.
  - **`semaphore-auth-body`: 1 KiB at most.** Nothing under `/api/auth` has a body.
- **The four OAuth values** are mounted as secret files (`semaphore.auth.<provider>.client-id` and `.client-secret`, written by Ansible, [runbook](../runbooks/oauth-applications.md)) that Spring reads as properties, and a second label, `oauth.hash`, from `OAUTH_HASH` in the stack's `.env`, makes Compose recreate the replicas when one changes, as `password.hash` does for the passwords. A provider whose two files are empty is off: the files exist, empty, before the applications are registered.
- **A test of the routes**, `tests/semaphore-edge/run.sh` (`make test-semaphore-edge`, a job of the CI): the real labels of `stacks/semaphore/compose.yaml` on a throwaway Traefik, with stubs for the backend and the front.

## Consequences

- **What the test shows**, with Traefik v3.7.16: `/api/me` and what is under `/api/` reach the backend, so does `/ws`; `/api`, `/apix`, `/ws/x`, `/actuator/health`, `/api/../actuator/health` and its encoded form end at the front; 30 `PUT /api/me` go through and the 31st is a 429, then another address still gets 200; a body of 2 KiB is a 413; `GET` and `DELETE` and a `PUT` elsewhere under `/api/` are not limited; `/api/auth` and what is under it reach the backend, `/api/authx` is an ordinary route of the API, 40 requests under `/api/auth` go through whatever the method and the next is a 429 while the rest of `/api` is still served and another address has its own bucket.
- **Order.** This is applied before the front that calls `/api/me` is deployed. Applied before the backend that serves it, `/api/me` answers the backend's 404, which the front reads as "no session" (semaphore ADR 0010), and the game goes on as it did.
- **What it does not stop.** A flood spread over many addresses: each one is held to 8 MB a week, a thousand of them are not. The answer to that is in semaphore ADR 0010 (a Valkey for the sessions alone, with an eviction policy), and is not worth its cost today.
- **A class of more than 30 pupils** behind one address gets the first 30 pseudos and the rest the name-per-room fallback, until the bucket refills a minute at a time.
- [ADR 0015](0015-the-game-behind-the-edge.md) said that nothing else of the backend is routed than `/ws`: it is now `/ws` and `/api/`.
