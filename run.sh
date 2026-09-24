#!/usr/bin/env sh
# Start validator-update-agent using config from .env.
#
#   ./run.sh               # uses ./.env
#   ./run.sh prod.env      # uses another env file
#   AGENT_BIN=/path/to/agent ./run.sh   # override binary location
#
# PUBKEY (in .env) must match the private key that signed manifest.json.
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ENV_FILE=${1:-"$SCRIPT_DIR/.env"}

# Locate the agent binary: $AGENT_BIN > next to script > sibling repo > $PATH.
if [ -n "${AGENT_BIN:-}" ]; then
  BIN="$AGENT_BIN"
elif [ -x "$SCRIPT_DIR/validator-update-agent" ]; then
  BIN="$SCRIPT_DIR/validator-update-agent"
elif [ -x "$SCRIPT_DIR/../validator-update-agent/validator-update-agent" ]; then
  BIN="$SCRIPT_DIR/../validator-update-agent/validator-update-agent"
else
  BIN="validator-update-agent"  # rely on $PATH
fi

if [ ! -f "$ENV_FILE" ]; then
  echo "run.sh: env file not found: $ENV_FILE" >&2
  exit 1
fi

set -a
. "$ENV_FILE"
set +a

exec "$BIN"
