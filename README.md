# Cloud Desktop on GitHub Actions

An always-on personal Linux desktop that lives on ephemeral GitHub Actions
runners, with automatic encrypted backup and restore of your home directory
between runners.

**Read the [Honest warnings](#honest-warnings) section before using this.**

## Architecture

```
 ┌───────────────────────── one runner session (≤ 5.5 h) ─────────────────────────┐
 │                                                                              │
 │  boot: restore /home/pc ──► XFCE + xrdp + Firefox + LibreOffice               │
 │        (rclone crypt pull     │                                               │
 │         from your cloud)      ▼                                               │
 │                        Tailscale tailnet ─── RDP from your devices            │
 │                        (stable name: cloudpc.<tailnet>.ts.net)               │
 │                                                                              │
 │  every 30 min: rclone snapshot → your cloud (encrypted)                      │
 │  at 5h30m:    final snapshot → `gh workflow run` with PAT → next runner       │
 └──────────────────────────────────────────────────────────────────────────────┘
```

- **Desktop:** XFCE (light, ~300–400 MB RAM) — runner has 4 vCPU / 16 GB.
- **Display protocol:** xrdp (RDP) — better compression/caching than raw VNC,
  native clients exist for Windows, macOS, iOS and Android.
- **Network:** Tailscale — encrypted WireGuard mesh, no ports exposed to the
  internet. The machine is unreachable by anyone outside your tailnet.
- **Persistence:** your cloud storage via rclone with a `crypt` remote, so the
  cloud provider never sees plaintext. Snapshots every 30 minutes plus a final
  sync; deletions are kept in a 7-day trash before being pruned.
- **Continuity:** each session re-triggers the next with your PAT. A daily
  scheduled run acts as a safety net if the chain ever breaks.

## One-time setup

Create the four repository secrets under **Settings → Secrets and variables →
Actions**.

### 1. `DESKTOP_PASSWORD`
The password you will type into the RDP login. Any string. (Username is `pc`.)

### 2. `RESTART_PAT`
A personal access token that can trigger this repo's workflows.

- GitHub → Settings → Developer settings → Personal access tokens →
  **Fine-grained tokens** → Generate new token.
- Repository access: **Only select repositories** → this repo.
- Permissions: **Actions → Read and write**.
- Paste the token as the secret value.
- Note the expiry date — when it expires, the chain stops until you replace it.

### 3. `TS_AUTHKEY`
A Tailscale auth key for your tailnet.

- Sign up free at tailscale.com, install Tailscale on the device(s) you'll
  connect from, log in once.
- Admin console → Settings → Keys → **Generate auth key**:
  - Reusable: **yes**
  - Ephemeral: **yes** (dead runners auto-disappear from your tailnet)
  - Tags: optional
- Paste the key (`tskey-auth-...`) as the secret value. Keys expire after a
  set period (max 90 days) — regenerate when it does.

### 4. `RCLONE_CONFIG`
The full contents of an rclone config file defining two remotes: your storage
(`backup:`) and an encrypted view of it (`crypt:`).

Do this once on your own computer (install rclone from rclone.org first):

```bash
rclone config
# n) new remote, name: backup
#   Storage: Google Drive (or Dropbox, OneDrive, S3, ... whatever you prefer)
#   Follow the OAuth flow in the browser.
#
# n) new remote, name: crypt
#   Storage: Encrypt/Decrypt a remote
#   remote to encrypt: backup:cloud-desktop
#   filename encryption: standard
#   directory name encryption: true
#   password + salt: let it generate, KEEP THEM SAFE (they're in the file)
```

Then paste the whole file as the secret:

```bash
cat ~/.config/rclone/rclone.conf
```

The file looks like:

```ini
[backup]
type = drive
token = {...}

[crypt]
type = crypt
remote = backup:cloud-desktop
password = <obfuscated>
password2 = <obfuscated>
```

## Start it

Actions tab → **cloud-desktop** workflow → **Run workflow**. The first run
creates an empty home; the chain keeps itself alive after that.

Connect from any device that has Tailscale installed and is logged into your
tailnet:

- RDP client (e.g. Microsoft Remote Desktop on any platform) → host
  `cloudpc.<your-tailnet-name>.ts.net`, port `3389`
- Username `pc`, password = your `DESKTOP_PASSWORD`.

## What persists and what doesn't

**Persists (restored on every boot):** everything under `/home/pc` minus
caches — documents, browser logins/profiles, dotfiles, installed-apt-user
configs, projects in your home.

**Does not persist:** system packages and `/etc` changes (each runner
reinstalls from scratch, ~4–6 min at boot), running programs, mounted
anything. If you want extra apt packages, add them to the workflow file so
every runner installs them.

## Stopping and restarting

- **Stop completely:** Actions → cloud-desktop → ⋯ → **Disable workflow**,
  then cancel any in-progress run. The schedule, the chain, everything stops.
- **Re-enable:** re-enable the workflow and either wait for the daily safety
  run or hit **Run workflow**.
- **One session only:** cancel the in-progress run *and* the queued one that
  follows it.

## Honest warnings

- **This is off-label use of GitHub Actions.** GitHub's terms say hosted
  runners are for building, testing, deploying and publishing the repo's
  software; anything else is out of scope, and enforcement can range from job
  termination to losing the repo or, in the worst case, the account. Keep the
  machine modest (light browsing/office), or expect attention.
- **There is a gap between sessions.** Each handoff costs roughly 5–8 minutes
  (queue + apt install + restore) before the next desktop is reachable.
- **The 6-hour cap is a hard kill.** Data changed in the last ≤30 minutes
  before an unplanned death can be lost — that's why snapshots are periodic,
  not just at shutdown.
- **Secrets rotate.** `RESTART_PAT` and `TS_AUTHKEY` have expiry dates; when
  either lapses, the chain or the tunnel dies until you refresh the secret.
- This repo is public by choice (free minutes). Secrets are never exposed to
  logs, and your data lives only in your encrypted rclone remote — but assume
  anything visible in a public repo or its logs is public.
