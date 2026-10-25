# 20. Two replicas of the backend

Date: 2026-10-25 · Status: accepted

## Context

The game's backend ran as one container with its rooms in memory ([ADR 0015](0015-the-game-behind-the-edge.md)): a deploy ended every game and a crash lost them. The backend now keeps its rooms in Redis and shares them between replicas ([ADR 0008 of semaphore](https://github.com/Didelo-lilian/semaphore/blob/main/docs/adr/0008-rooms-in-redis-shared-by-replicas.md)), Valkey runs on the server ([ADR 0018](0018-redis-for-the-games-rooms.md)) and `deploy-app` replaces replicas one at a time with a canary ([ADR 0019](0019-rolling-and-canary-deploys.md)). This change runs two replicas.

## Decision

- **Two replicas, `deploy.replicas: 2`, and no sticky sessions.** Traefik picks a replica for each WebSocket handshake. The room code only arrives in the first message, after that choice, so it cannot route by room; and two players of one room are two browsers that land on different replicas anyway. Any replica serves a `rejoin`.
- **The backend joins the internal `game` network in addition to `edge`.** Traefik is told which one to use for routing (`--providers.docker.network=edge`), so it never picks the internal address.
- **The Redis address, password included, comes from a secret file.** Ansible writes `redis://:<password>@redis:6379` to `/srv/stacks/semaphore/secrets/semaphore.redis-url` (`root:10001`, `0440`; 10001 is the image's user, which nothing else on the host has), Compose mounts it as a secret and Spring Boot reads the directory as configuration (`SPRING_CONFIG_IMPORT=configtree:/run/secrets/`): the file name is the property `semaphore.redis-url`. An environment variable would have put the password in the Compose file or in `docker inspect`. Spring reads it at start only, so the hash of the password is a label of the service, as for Redis: a rotation recreates both in the same run.
- **Redis stays out of the backend's health check** (the semaphore ADR 0008). A Redis outage must not take both replicas out of Traefik, nor fail a canary for a fault that is not in the image. [ADR 0018](0018-redis-for-the-games-rooms.md) said the opposite and is amended. Two alerts replace it: `RedisMissing` (no Redis container for 2 minutes) and `BackendReplicaMissing` (fewer than two backend containers for 5 minutes; a rollout starts the new replica before it removes the old one, so a healthy deploy never goes below two).
- **Memory.** The second backend adds 384 MiB to the 2,240 MiB of limits of [ADR 0018](0018-redis-for-the-games-rooms.md), which already counted it: 2,816 MiB, about a third of the server.

## Consequences

**Order.** The image that reads `semaphore.redis-url` must be merged and running before this change is applied. Applied before, each replica would ignore the file and keep its rooms in memory, and half of the players of a room would get "no such room". Applying it recreates the backend once (a few seconds without the game, and the games in progress end, as at every deploy until now).

Checked with the real Compose files of `stacks/redis` and `stacks/semaphore` (only the router's host, the pull policy and the per-address cap of 24 changed, in an override file), the real Traefik v3.7.16, and the image of the backend built from the pull request that adds Redis:
- **The password is nowhere to be read.** `docker inspect` of the backend and of Redis contains it zero times. A file `root:10001` `0440` is read by the image's user.
- **Both replicas play.** The k6 load test of semaphore (50 tables of five connections for 30 seconds, through Traefik): 509 games finished out of 509, no protocol error, a command answered in 3 ms (median) and 33 ms (p95). The two replicas moved the same traffic (64 MB and 66 MB received) and used about 295 MiB each of their 384 MiB.
- **A replica can die.** With a room of four players, `docker kill` of one replica: the four players rejoined through Traefik with their tokens, the room still held four players, a command (a team choice) reached the others, and after the replica restarted a `rejoin` still found the room.
- **Redis can go away.** With Redis stopped for 40 seconds both replicas stayed healthy; a new room got "the server is busy, try again" on a connection that stayed open; once Redis was back the room created before the outage was found (the append-only file) and new rooms worked.

Limits:
- **A dead replica takes its connections with it.** The browsers reconnect and `rejoin` on their own; nothing else is lost.
- **Redis is still one process.** While it is down nobody can create, join or play, and the health check does not say so. `RedisMissing` covers a container that is gone, not one that runs and answers nothing.
- **The cap of 24 open connections per address stays in Traefik**, before it picks a replica, so it still counts every connection of an address.
