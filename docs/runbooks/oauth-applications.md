# Registering the OAuth applications of the game

The game signs players in with GitHub or Google ([semaphore ADR 0011](https://github.com/Didelo-lilian/semaphore/blob/main/docs/adr/0011-sign-in-with-github-or-google.md)). Each provider needs an application registered by hand, because only its owner can create one. This is what to create, with which values, and where the four results go. The screens of both providers move often: the fields below matter, not the menu names.

Nothing here is needed to run the game: a provider whose two values are blank is simply off, and the game works for guests.

## What the backend needs from each

| Provider | Callback address (exactly) | Scope | Gives back |
|---|---|---|---|
| GitHub | `https://play.didelo.fr/api/auth/callback/github` | none | a client id and a client secret |
| Google | `https://play.didelo.fr/api/auth/callback/google` | `openid` | a client id and a client secret |

The backend keeps nothing but the provider's user id: no e-mail, no name, no avatar.

## GitHub

1. Open the organization `Didelo-lilian` → Settings → Developer settings → OAuth Apps → New OAuth App.
2. Fill in:
   - **Application name**: `Sémaphore`
   - **Homepage URL**: `https://play.didelo.fr`
   - **Authorization callback URL**: `https://play.didelo.fr/api/auth/callback/github` (an OAuth App takes one address only: a second environment needs its own application)
   - Leave **Enable Device Flow** off.
3. Register the application. The page shows the **Client ID**.
4. Click **Generate a new client secret** and copy it right away: it is shown once.

## Google

1. Open the Google Cloud console and create a project (for example `didelo`), or pick an existing personal one.
2. Open Google Auth Platform (formerly "OAuth consent screen") and set it up:
   - **App name**: `Sémaphore`; **support e-mail** and **contact e-mail**: yours.
   - **Audience**: External.
   - **Data access**: the scope `openid` only (a non-sensitive scope: no review by Google is expected for it).
   - **Branding**: the values of the table below, with the authorized domain `didelo.fr`.
3. Publish the app (Audience → **Publish app**, status "In production") once the three addresses of the table answer in a private window. In "Testing" only the listed test users can sign in.
4. Clients → Create client → **Web application**, named `semaphore`:
   - **Authorized redirect URIs**: `https://play.didelo.fr/api/auth/callback/google`
   - No JavaScript origin is needed: the exchange happens on the server.
5. Copy the **Client ID** and the **Client secret** from the dialog now: Google may not show the secret again.

### Google's branding values

An app in production needs a home page that describes it, a privacy policy and terms of use, on a domain declared as authorized. The three pages are routes of the front, so they are live as soon as it is deployed.

| Field | Value |
|---|---|
| App logo | `front/public/logo-120.png` of the `semaphore` repository (PNG, 120×120, under 1 MB; Google takes a file, not an address) |
| Application home page | `https://play.didelo.fr` |
| Application privacy policy link | `https://play.didelo.fr/privacy` |
| Application terms of service link | `https://play.didelo.fr/terms` |
| Authorized domains | `didelo.fr` |

The privacy and terms links must be the same on the home page and on the consent screen: Google checks that they match. The home page links to both from its footer, so these two addresses do not change without the front changing too.

The GitHub application can take the same logo (optional): `front/public/logo-512.png` on its page, under **Application logo**.

## Store the four values

The values go in the encrypted file, never in the chat, in an issue or in a Compose file ([ADR 0007](../adr/0007-secrets-with-sops-and-age.md)):

```bash
cd ~/Projects/didelo/main/infra   # or a worktree of infra on a new branch
sops secrets/production.sops.yaml
```

Add four lines in the editor, then save. Keep the quotes: a client id of digits with an `e` in the middle would otherwise be read as a number and stored altered.

```yaml
GITHUB_CLIENT_ID: "<from GitHub>"
GITHUB_CLIENT_SECRET: "<from GitHub>"
GOOGLE_CLIENT_ID: "<from Google>"
GOOGLE_CLIENT_SECRET: "<from Google>"
```

Open a pull request (`chore(secrets): add the OAuth client settings of the game`) and merge it. The dry run cannot see secrets, so run the **Server** workflow by hand with `force` and approve it: the task `Write the sign-in settings` writes one file per value in `/srv/stacks/semaphore/secrets/` and shows `changed`. Nothing reads them yet: the backend does once the sign-in code is deployed and a later change of `stacks/semaphore` mounts the files and adds them to the hash label. Until then a run with `force` only rewrites the files and restarts nothing.

A provider can be added alone: leave the other two lines out and its two files stay empty.

## If a secret leaks

Generate a new client secret at the provider (GitHub: the application's page; Google: the client's page, "Add secret", then disable the old one), put it in the file with `sops`, merge, and run **Server** with `force`. The old secret is dead as soon as it is deleted at the provider.
