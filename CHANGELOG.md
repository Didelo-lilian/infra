# Changelog

## [0.3.0](https://github.com/Didelo-lilian/infra/compare/v0.2.0...v0.3.0) (2026-10-25)


### Features

* **deploy-app:** update replicas one at a time with a canary and roll back on failure ([b01b342](https://github.com/Didelo-lilian/infra/commit/b01b342666e22dd3f62ff032461d769b269bc2d0))
* **play:** serve the game on play.didelo.fr ([#71](https://github.com/Didelo-lilian/infra/issues/71)) ([18e2e6f](https://github.com/Didelo-lilian/infra/commit/18e2e6f755a6826d3a9ece3a6f7c3ecb826f59ce)), closes [#70](https://github.com/Didelo-lilian/infra/issues/70)
* **redis:** run Valkey for the game's rooms on a private network ([#86](https://github.com/Didelo-lilian/infra/issues/86)) ([c3468fe](https://github.com/Didelo-lilian/infra/commit/c3468fe2c7163e542494f3d867fcde5047dfd99c))
* **semaphore:** run two replicas of the backend that share their rooms in Redis ([2b39c24](https://github.com/Didelo-lilian/infra/commit/2b39c24623cce8d594b39b233a85613475dbf55b))


### Bug fixes

* **semaphore:** let the deploy user read the stack's .env ([0001a30](https://github.com/Didelo-lilian/infra/commit/0001a30f51ff578244c5b060c9f752d03c115e78))


### Documentation

* **adr:** correct what the plugin volume does and accept a catalog outage ([#80](https://github.com/Didelo-lilian/infra/issues/80)) ([4113db8](https://github.com/Didelo-lilian/infra/commit/4113db88841abcaa7af5edac7cca128b475ae1a4))

## [0.2.0](https://github.com/Didelo-lilian/infra/compare/v0.1.0...v0.2.0) (2026-10-24)


### Features

* **crowdsec:** add the AppSec WAF with virtual patching and OWASP CRS ([#60](https://github.com/Didelo-lilian/infra/issues/60)) ([63f9325](https://github.com/Didelo-lilian/infra/commit/63f932528b8a00107cda6c7a65c5d442e0702839)), closes [#51](https://github.com/Didelo-lilian/infra/issues/51)
* **crowdsec:** ban SSH attackers at the host firewall ([#58](https://github.com/Didelo-lilian/infra/issues/58)) ([53c6968](https://github.com/Didelo-lilian/infra/commit/53c6968bbdc75e2a7fc1f0cb993e65e1f51661b9)), closes [#49](https://github.com/Didelo-lilian/infra/issues/49)
* **crowdsec:** block banned IPs at Traefik, failing open ([#56](https://github.com/Didelo-lilian/infra/issues/56)) ([9ba23c4](https://github.com/Didelo-lilian/infra/commit/9ba23c4c52f1049415fa38752a8d8ca54246acfe)), closes [#48](https://github.com/Didelo-lilian/infra/issues/48)
* **deploy:** add a deploy-app workflow with a restricted SSH key ([#40](https://github.com/Didelo-lilian/infra/issues/40)) ([35d5d32](https://github.com/Didelo-lilian/infra/commit/35d5d32d05e4d86cbfa0a5e84a589bfcb070fdf8))
* **dns:** point status.didelo.fr to GitHub Pages ([#25](https://github.com/Didelo-lilian/infra/issues/25)) ([6bb3326](https://github.com/Didelo-lilian/infra/commit/6bb3326c40123a98bdab1195095c61f2457ea7f4))
* **ds:** serve the design system Storybook on ds.didelo.fr ([#38](https://github.com/Didelo-lilian/infra/issues/38)) ([5b1d8c3](https://github.com/Didelo-lilian/infra/commit/5b1d8c33bdbdada59917637c92b5ad6a9ec36c50))
* **edge:** add a CSP on hello and a Permissions-Policy everywhere ([#61](https://github.com/Didelo-lilian/infra/issues/61)) ([4a46531](https://github.com/Didelo-lilian/infra/commit/4a465318cb41e120d517e86a85ca3e8961142d27)), closes [#52](https://github.com/Didelo-lilian/infra/issues/52)
* **monitoring:** add per-container metrics with cAdvisor ([#47](https://github.com/Didelo-lilian/infra/issues/47)) ([9e3f745](https://github.com/Didelo-lilian/infra/commit/9e3f745c5e1955251584ae6448dcd1aba2bcdfdf)), closes [#46](https://github.com/Didelo-lilian/infra/issues/46)
* **monitoring:** monitor the platform with prometheus and grafana ([#26](https://github.com/Didelo-lilian/infra/issues/26)) ([49cf358](https://github.com/Didelo-lilian/infra/commit/49cf3582c64eda861ad715b091d3447cdd8ac30f))
* **monitoring:** publish a public metrics dashboard on metrics.didelo.fr ([#65](https://github.com/Didelo-lilian/infra/issues/65)) ([8d1de50](https://github.com/Didelo-lilian/infra/commit/8d1de50cdce8bad1f93f4ffa73b1e56a4590b3c1)), closes [#45](https://github.com/Didelo-lilian/infra/issues/45)
* **monitoring:** scrape CrowdSec and Traefik and add a security dashboard ([#64](https://github.com/Didelo-lilian/infra/issues/64)) ([0e4b619](https://github.com/Didelo-lilian/infra/commit/0e4b6193007c7dfa620a1ef3667f07bd2440e4dd)), closes [#53](https://github.com/Didelo-lilian/infra/issues/53)
* **secrets:** configure SOPS and reject plaintext in secrets/ ([#32](https://github.com/Didelo-lilian/infra/issues/32)) ([b34d24f](https://github.com/Didelo-lilian/infra/commit/b34d24ff6a324d185cb3b1bd834966ae8a687719)), closes [#31](https://github.com/Didelo-lilian/infra/issues/31)
* **secrets:** read the SMTP password from the SOPS file ([#34](https://github.com/Didelo-lilian/infra/issues/34)) ([63afa59](https://github.com/Didelo-lilian/infra/commit/63afa591818fdccf8073eaed1fca612dfa89e1ef)), closes [#33](https://github.com/Didelo-lilian/infra/issues/33)
* **security:** read the Traefik and SSH logs with CrowdSec ([#55](https://github.com/Didelo-lilian/infra/issues/55)) ([9eb4c76](https://github.com/Didelo-lilian/infra/commit/9eb4c7691ed70aec4c36ba1267979c4e2f58032a)), closes [#54](https://github.com/Didelo-lilian/infra/issues/54)
* **traefik:** rate limit and cap open requests per IP ([#59](https://github.com/Didelo-lilian/infra/issues/59)) ([334ab3b](https://github.com/Didelo-lilian/infra/commit/334ab3b03567519472af3bae51b5d4a8ef37cf60)), closes [#50](https://github.com/Didelo-lilian/infra/issues/50)


### Bug fixes

* **ansible:** read the bouncer key only outside the dry run ([#57](https://github.com/Didelo-lilian/infra/issues/57)) ([ebc18ed](https://github.com/Didelo-lilian/infra/commit/ebc18ed7d3429f08d7f76a1593f66373bfd637ec)), closes [#48](https://github.com/Didelo-lilian/infra/issues/48)
* **deploy:** roll out app updates without downtime ([#42](https://github.com/Didelo-lilian/infra/issues/42)) ([061e389](https://github.com/Didelo-lilian/infra/commit/061e3897c8ffa550cfab7ce58c92cbfe69e19ea6))
* **edge:** hide nginx and server versions from responses ([#28](https://github.com/Didelo-lilian/infra/issues/28)) ([c9bd2e4](https://github.com/Didelo-lilian/infra/commit/c9bd2e471a47a5c5d20b70ab45fa33de4e7b7cbc))
* **hello:** recreate the container when its nginx config changes ([#62](https://github.com/Didelo-lilian/infra/issues/62)) ([7bd243e](https://github.com/Didelo-lilian/infra/commit/7bd243e8729b33216c0c2d439b5f971ae0a56e5e)), closes [#52](https://github.com/Didelo-lilian/infra/issues/52)
* **monitoring:** redirect the metrics home when it has a query string ([#67](https://github.com/Didelo-lilian/infra/issues/67)) ([7d98bd1](https://github.com/Didelo-lilian/infra/commit/7d98bd1c07542910dfbd78db3305824ddd5d6224)), closes [#45](https://github.com/Didelo-lilian/infra/issues/45)
* **monitoring:** stop the public metrics page from failing requests in the console ([#66](https://github.com/Didelo-lilian/infra/issues/66)) ([49c6f78](https://github.com/Didelo-lilian/infra/commit/49c6f78da466b311f054212855cadc5b4ca5453c)), closes [#45](https://github.com/Didelo-lilian/infra/issues/45)


### Documentation

* add a runbook to rotate secrets and age keys ([#36](https://github.com/Didelo-lilian/infra/issues/36)) ([f3a0a88](https://github.com/Didelo-lilian/infra/commit/f3a0a88d3c16efab8d28405bd3be92fe3f146fc1)), closes [#35](https://github.com/Didelo-lilian/infra/issues/35)
* add ADR 0007 on secrets with SOPS and age ([#30](https://github.com/Didelo-lilian/infra/issues/30)) ([34d05b8](https://github.com/Didelo-lilian/infra/commit/34d05b8b46ba09023350c7041e9c058df8e55522)), closes [#29](https://github.com/Didelo-lilian/infra/issues/29)
* bring the architecture diagram up to date ([#69](https://github.com/Didelo-lilian/infra/issues/69)) ([972c536](https://github.com/Didelo-lilian/infra/commit/972c5361064d37484c7341cfa903e38ad1656d41)), closes [#68](https://github.com/Didelo-lilian/infra/issues/68)
* link the changelog and releases from the readme ([#21](https://github.com/Didelo-lilian/infra/issues/21)) ([9067343](https://github.com/Didelo-lilian/infra/commit/9067343e3413ce65a5c8d09f7ba3b3abb78f281d))
* show the npm package in the architecture diagram ([#44](https://github.com/Didelo-lilian/infra/issues/44)) ([8df37c0](https://github.com/Didelo-lilian/infra/commit/8df37c0b41d3f60afa6a2558126e45bed2a3b8f8)), closes [#43](https://github.com/Didelo-lilian/infra/issues/43)
* show the SSL Labs and Security Headers grades ([#63](https://github.com/Didelo-lilian/infra/issues/63)) ([84d3d5c](https://github.com/Didelo-lilian/infra/commit/84d3d5caf366204a697717917f86cc4ae539a62f)), closes [#52](https://github.com/Didelo-lilian/infra/issues/52)

## 0.1.0 (2026-10-22)


### Features

* bootstrap Terraform, CI and releases ([#2](https://github.com/Didelo-lilian/infra/issues/2)) ([12802b2](https://github.com/Didelo-lilian/infra/commit/12802b2cad149bac0009131bb2e70f0a3853ef0f))
* **ci:** apply Terraform from CI after manual approval ([#9](https://github.com/Didelo-lilian/infra/issues/9)) ([444c28c](https://github.com/Didelo-lilian/infra/commit/444c28c306df78d94ea95430beeadd1931d14743))
* **dns:** point didelo.fr to the VPS and lock down mail ([#7](https://github.com/Didelo-lilian/infra/issues/7)) ([acf048d](https://github.com/Didelo-lilian/infra/commit/acf048d007c9391f34faaef9c83751a27910cf23))
* **edge:** serve hello.didelo.fr over HTTPS with Traefik ([#13](https://github.com/Didelo-lilian/infra/issues/13)) ([90f25bf](https://github.com/Didelo-lilian/infra/commit/90f25bf111f243f8a0e1ea5a947b1e330edd1178))
* **server:** configure the VPS with an Ansible playbook ([#11](https://github.com/Didelo-lilian/infra/issues/11)) ([ec6a4b2](https://github.com/Didelo-lilian/infra/commit/ec6a4b26bb29548da3ab45acb297531e595e7c51))


### Bug fixes

* **ci:** make the server workflow valid yaml and lint workflows ([#19](https://github.com/Didelo-lilian/infra/issues/19)) ([79c3fa5](https://github.com/Didelo-lilian/infra/commit/79c3fa5d80cf9504954a9aa3b0cc750ce5a22a74))
* start versions at 0.1.0 ([#5](https://github.com/Didelo-lilian/infra/issues/5)) ([02a151a](https://github.com/Didelo-lilian/infra/commit/02a151a4ea6f92762a06dd3f3cf6c2ae797b05be))


### Documentation

* add an architecture diagram to the readme ([#16](https://github.com/Didelo-lilian/infra/issues/16)) ([14b6c4d](https://github.com/Didelo-lilian/infra/commit/14b6c4d1e6b00795aabfd7eacce63185cea4d6b3))
