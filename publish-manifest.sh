#!/usr/bin/env sh
# publish-manifest.sh — sign manifest.json, then commit + push it to GitHub so
# the validator-update-agent picks up the new release.
#
# Workflow:
#   1) edit manifest.json   (bump "version" / "seq" / images)
#   2) ./publish-manifest.sh          # sign + verify + commit + push
#   3) ./run.sh                       # or: DRY_RUN=1 ./run.sh   (to test)
#
# Flags:
#   --no-push   sign + commit only (skip git push)
#   --test      after publishing, run ./run.sh with DRY_RUN=1
#
# AGENT_BIN=/path/to/binary overrides where the agent binary is found.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
cd "$SCRIPT_DIR"

MANIFEST="manifest.json"
SIG="$MANIFEST.sig"
PRIV="agent-priv.b64"

# Locate the agent binary: $AGENT_BIN > next to script > sibling repo > $PATH.
if [ -n "${AGENT_BIN:-}" ]; then BIN="$AGENT_BIN"
elif [ -x "$SCRIPT_DIR/validator-update-agent" ]; then BIN="$SCRIPT_DIR/validator-update-agent"
elif [ -x "$SCRIPT_DIR/../validator-update-agent/validator-update-agent" ]; then BIN="$SCRIPT_DIR/../validator-update-agent/validator-update-agent"
else BIN="validator-update-agent"
fi

DO_PUSH=1; RUN_TEST=0
for a in "$@"; do
  case "$a" in
    --no-push) DO_PUSH=0 ;;
    --test)    RUN_TEST=1 ;;
    *) echo "unknown flag: $a" >&2; exit 2 ;;
  esac
done

[ -f "$MANIFEST" ] || { echo "!! $MANIFEST not found" >&2; exit 1; }
[ -f "$PRIV" ]     || { echo "!! $PRIV not found (generate: $BIN keygen $PRIV)" >&2; exit 1; }

echo ">> signing $MANIFEST"
"$BIN" sign "$PRIV" "$MANIFEST"

# Local verify: run the agent briefly against the local file and fail on a bad signature.
if [ -f .env ]; then
  PUBKEY=$(. ./.env; printf '%s' "${PUBKEY:-}")
  if [ -n "$PUBKEY" ]; then
    echo ">> verifying signature against PUBKEY from .env"
    out=$(MANIFEST_URL="file://$SCRIPT_DIR/$MANIFEST" PUBKEY="$PUBKEY" POLL_INTERVAL=1h DRY_RUN=1 "$BIN" 2>&1 &
          p=$!; sleep 3; kill "$p" 2>/dev/null; wait "$p" 2>/dev/null) || true
    if printf '%s\n' "$out" | grep -q 'signature INVALID'; then
      echo "!! signature INVALID — agent-priv.b64 does not match PUBKEY. Not publishing." >&2
      exit 1
    fi
    echo "   signature OK"
  fi
fi

VER=$(grep -o '"version"[^,}]*' "$MANIFEST" | head -1 | sed 's/.*: *//; s/[" ]//g')
SEQ=$(grep -o '"seq"[^,}]*'     "$MANIFEST" | head -1 | sed 's/.*: *//; s/[" ]//g')

echo ">> staging $MANIFEST + $SIG"
git add "$MANIFEST" "$SIG"
if git diff --cached --quiet; then
  echo "   no changes to commit"
else
  git commit -m "chore: update manifest${VER:+ to $VER}${SEQ:+ (seq $SEQ)}"
fi

if [ "$DO_PUSH" -eq 1 ]; then
  BR=$(git branch --show-current)
  echo ">> pushing to origin/$BR"
  git push
  echo "   published — raw CDN may cache the old file for a few minutes"
else
  echo ">> --no-push: skipped git push"
fi

if [ "$RUN_TEST" -eq 1 ]; then
  echo ">> ./run.sh (DRY_RUN=1)"
  DRY_RUN=1 ./run.sh
fi
