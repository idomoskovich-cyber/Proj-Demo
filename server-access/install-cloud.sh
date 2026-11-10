#!/usr/bin/env bash
set -euo pipefail
cd /workspace/server-access
command -v ssh >/dev/null
command -v ssh-keygen >/dev/null
XDG_CACHE_HOME=/workspace/server-access/cache bash /workspace/server-access/ensure-socat.sh >/dev/null
# The environment snapshot must retain this identity; never replace it silently.
test -s /workspace/server-access/ssh/id_ed25519
test -s /workspace/server-access/ssh/id_ed25519.pub
chmod 0700 /workspace/server-access/ssh
chmod 0600 /workspace/server-access/ssh/id_ed25519
bash -n /workspace/server-access/ssh-command.sh
