# 8. Serve a static site from another repository through a moving image tag

Date: 2026-10-23 · Status: accepted; the deploy trigger is replaced by [ADR 0009](0009-deploy-app-updates-without-approval.md)

## Context

The Storybook of [design-system](https://github.com/Didelo-lilian/design-system) must be online at https://ds.didelo.fr and follow every merge to its `main`. This repository deploys by copying `stacks/` with Ansible, and the build lives in another repository. Options for the bridge:
- a pull request to `infra` on every change, pinning an image tag: reproducible, but each merge needs a second review and a second merge;
- the ephemeral self-hosted runner pool: not there yet;
- a public image on GHCR whose `main` tag follows the repository, pulled by the server.

## Decision

`stacks/ds` runs `ghcr.io/didelo-lilian/design-system:main`, an nginx image with the static build, with `pull_policy: always`.

- The module `community.docker.docker_compose_v2` has `pull: policy` by default, which follows the Compose file: no `pull:` option is needed in the playbook.
- When a merge to `main` in `design-system` has pushed the image, its CD calls the **Server** workflow here through `workflow_dispatch` with `force=true`, using a token of the `didelo-release` GitHub App that only has `actions: write` on this repository. The workflow already accepts that trigger: the dry run, then the approval in the `production` environment, are unchanged. Nothing deploys without my click.
- The image is public, so the server needs no registry credential. `ds` runs read-only, non-root, with `no-new-privileges` and a memory limit, like `hello`.
- The `X-Frame-Options` header becomes `SAMEORIGIN` (`customFrameOptionsValue`, which overrides `frameDeny`) for every site: Storybook shows its stories in an iframe of its own origin. Framing from any other site stays refused.
- Prometheus probes https://ds.didelo.fr like every other site, and the existing alerts apply to it.

## Consequences

- A moving tag is not reproducible: a deploy from the same commit of `infra` can run different content, and the dry run cannot show that the image changed. A bad image is rolled back by pinning a previous `sha-…` tag in the Compose file through a pull request, or by re-running the failed build.
- The Server workflow also runs for a change that only touched `design-system`: with `force=true` it applies even when the dry run shows nothing, and the pulled image is the only change.
- The App token can start workflows here: it is as powerful as the approval is strict. The approval in `production` is what keeps a compromised `design-system` from deploying on its own.
- When the runner pool exists, `design-system` can deploy from its own pipeline and this bridge goes away.
