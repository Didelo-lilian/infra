# 16. The Ansible collections come from GitHub, pinned by commit

Date: 2026-10-24 · Status: accepted

## Context

The `ansible` check and the `Server` workflow (which installs the collections twice, to check and to apply) read `ansible/requirements.yml` and downloaded the four collections from Galaxy. On 24 October every download answered HTTP 500 for hours: the `ansible` check of a pull request stayed red, and the next `Server` run, the one that deploys, would have failed the same way. Galaxy publishes no status page, so there was nothing to wait for but a `curl` that kept answering 500.

## Decision

- **The collections are installed from their GitHub repositories** (`type: git` in `requirements.yml`), at a **pinned commit**, with the tag in a comment. GitHub is already what the pipeline cannot work without; Galaxy was a second dependency of the same kind that failed on its own.
- **A commit, not a tag**: a tag can be moved, a commit cannot. For an annotated tag the commit is the line ending in `^{}` in `git ls-remote --tags <repo> <tag> '<tag>^{}'`.
- **The shared dependency is listed too**: `community.docker` and `community.general` depend on `community.library_inventory_filtering_v1`, and `ansible-galaxy` looks a dependency up on Galaxy unless it is already in the file.
- **Nothing else changes**: the workflows still run `ansible-galaxy collection install -r requirements.yml`, and so does the lint action; `git` is on the runners.

## Consequences

- Installed on an empty collections path with Galaxy replaced by an unreachable address: the four collections and the dependency install at the same versions, and `ansible-lint` passes on the production profile.
- Bumping a collection is a manual edit of two lines (commit and tag comment), like the version before. Nothing updates these versions on its own: Dependabot does not read `requirements.yml`.
- The Python packages still come from PyPI, with hashes (`requirements.txt`). That is another registry the pipeline relies on; it has not failed so far.
