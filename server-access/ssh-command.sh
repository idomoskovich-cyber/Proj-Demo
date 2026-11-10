#!/usr/bin/env bash
# Run using an approved outer execution command: proxy:8088 is outside bubblewrap.
set -euo pipefail
root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
[[ $# -ge 1 ]] || { printf 'Usage: bash %s SERVER_HOST [REMOTE_COMMAND ...]\n' "$0" >&2; exit 2; }
server_host="$1"
shift
[[ "$server_host" =~ ^[A-Za-z0-9][A-Za-z0-9.-]*$ ]] || { printf 'Use a validated IPv4 address or DNS hostname.\n' >&2; exit 2; }
[[ -s "$root/ssh/known_hosts" ]] || { printf 'Server host key not registered. Obtain its public host key from the local server Shell first.\n' >&2; exit 2; }
[[ -s "$root/ssh/id_ed25519" ]] || { printf 'Dedicated SSH private key is missing. Do not silently regenerate it.\n' >&2; exit 2; }
socat_bin="$(XDG_CACHE_HOME="$root/cache" bash "$root/ensure-socat.sh")"
if [[ $# -eq 0 ]]; then
  set -- 'id && hostname && sudo -n true'
fi
exec ssh -F /dev/null -T -p 22 \
  -o BatchMode=yes -o IdentitiesOnly=yes -o IdentityAgent=none \
  -o StrictHostKeyChecking=yes -o UpdateHostKeys=no \
  -o UserKnownHostsFile="$root/ssh/known_hosts" -o GlobalKnownHostsFile=/dev/null \
  -o HostKeyAlias=chatgpt-user-server -o HostKeyAlgorithms=ssh-ed25519 \
  -o ConnectTimeout=15 -o ConnectionAttempts=1 \
  -o ServerAliveInterval=30 -o ServerAliveCountMax=3 \
  -o "ProxyCommand=\"$socat_bin\" STDIO PROXY:proxy:%h:%p,proxyport=8088,resolve=0,connect-timeout=15" \
  -i "$root/ssh/id_ed25519" "chatgpt-agent@$server_host" "$@"
