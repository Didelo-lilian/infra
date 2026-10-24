# Bouncer plugin, loaded from disk

`src/github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin` is a copy of <https://github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin> (Apache-2.0, see its `LICENSE`) at tag `v1.8.1`, commit `f9c85b1472d618e9188a025c9b2308d0b27e5321`. Why it is here and not downloaded: [ADR 0017](../../../docs/adr/0017-the-bouncer-plugin-is-read-from-disk.md).

Left out of the copy: tests, examples, CI and Docker files, the icon, the README. Kept: everything Traefik's interpreter reads. One line differs from upstream: the plugin's dummy test key in `.traefik.yml` carries `# gitleaks:allow`, because the secret scan takes it for a real key.

## Bump it

```bash
git clone --depth 1 --branch <tag> https://github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin /tmp/plugin
rsync -a --delete --exclude='.git' --exclude='.github' --exclude='.assets' --exclude='examples' --exclude='tests' \
  --exclude='docker-compose*.yml' --exclude='Makefile' --exclude='renovate.json' --exclude='.golangci.yml' \
  --exclude='acquis.yaml' --exclude='README.md' --exclude='.gitignore' --exclude='*_test.go' \
  /tmp/plugin/ src/github.com/maxlerebourg/crowdsec-bouncer-traefik-plugin/
git -C /tmp/plugin rev-parse HEAD   # the commit to write above, with the tag
```

The copy overwrites the `# gitleaks:allow` comment: put it back on the `CrowdsecLapiKey` line of `.traefik.yml`.

Then check on a throwaway Traefik before merging: the real files of `stacks/traefik/dynamic`, the catalog made unreachable (`--add-host plugins.traefik.io:127.0.0.1`), a read-only container, and a request through the bouncer that answers 200. Read the release notes for new settings: the middleware in `dynamic/crowdsec.yml` must keep failing open.
