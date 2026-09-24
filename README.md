# Validator update manifest

Signed release manifest for [`validator-update-agent`](https://github.com/tuyencaovn/validator-update-agent).
The agent polls `manifest.json`, verifies its detached signature (`manifest.json.sig`)
against a fixed ed25519 public key, and keeps the matching containers on the version
declared here.

## Files

| File | Committed | Purpose |
|------|-----------|---------|
| `manifest.json` | yes | The release manifest (versions per image group). |
| `manifest.json.sig` | yes | Detached ed25519 signature over the exact bytes of `manifest.json`. |
| `agent-priv.b64` | **no** (gitignored) | Private signing key. Never commit. |
| `.env` | **no** (gitignored) | Local run config incl. Slack webhook. Never commit. |
| `run.sh` | yes | Load `.env` and start the agent. |
| `publish-manifest.sh` | yes | Sign, verify, commit and push a manifest change. |

## URLs

The agent must fetch the **raw** URL, not the `github.com/.../blob/...` page
(the blob page returns HTML, which fails signature verification):

```
https://raw.githubusercontent.com/tuyencaovn/public/main/manifest.json
https://raw.githubusercontent.com/tuyencaovn/public/main/manifest.json.sig
```

## Keys

Generate a keypair once. The private key stays local; the printed `PUBKEY` goes
into the agent's config (`.env`) and must match whoever signs the manifest.

```sh
../validator-update-agent/validator-update-agent keygen agent-priv.b64
```

## Publish a new release

1. Edit `manifest.json` — bump `version`, **increment `seq`** (monotonic, guards
   against replay/downgrade), and/or change the image list.
2. Sign, verify, commit and push:

   ```sh
   ./publish-manifest.sh            # sign + verify + commit + push
   ./publish-manifest.sh --test     # also run ./run.sh (DRY_RUN=1) afterwards
   ./publish-manifest.sh --no-push  # sign + commit only
   ```

   The script refuses to publish if `agent-priv.b64` does not match the `PUBKEY`
   in `.env`. After a push, GitHub's raw CDN may serve the old file for a few
   minutes.

## Run / test the agent

Config lives in `.env` (gitignored). Example:

```sh
MANIFEST_URL="https://raw.githubusercontent.com/tuyencaovn/public/main/manifest.json"
PUBKEY="<base64 ed25519 public key>"
SLACK_WEBHOOK_URL="https://hooks.slack.com/services/XXX/YYY/ZZZ"
VALIDATOR_READYZ_URL="http://localhost:5003/api/validator/readyz"
POLL_INTERVAL="50m"
# DRY_RUN="1"   # log actions without touching containers
```

Then:

```sh
./run.sh              # start the agent
DRY_RUN=1 ./run.sh    # test without changing any container
```

The agent only acts on **already-running** containers whose short image name
appears in the manifest. If none match, it logs `no managed containers running`
and does nothing — it never bootstraps a new container.
