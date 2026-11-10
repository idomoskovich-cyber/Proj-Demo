#!/usr/bin/env bash
# Run locally in the Proxmox node Shell, as root. Never in the cloud executor.
set -euo pipefail
umask 077
fail() { printf '%s\n' "$*" >&2; exit 1; }
[[ $EUID -eq 0 ]] || fail 'Run this in the Proxmox node Shell as root.'
command -v pveversion >/dev/null || fail 'Expected a Proxmox host. Stop and confirm the server OS before proceeding.'

account=chatgpt-agent
account_home=/home/chatgpt-agent
marker=/var/lib/chatgpt-cloud-access
public_key='ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJaHm1+Gr+uDEY9VB7aKQ/EfCzP9kFVjr8pRlDOoxj6M chatgpt-cloud-server-access'
sudo_rule='chatgpt-agent ALL=(ALL:ALL) NOPASSWD: ALL'
sudo_file=/etc/sudoers.d/90-chatgpt-agent

if id "$account" >/dev/null 2>&1; then
  [[ -f "$marker/managed-account" ]] || fail 'An unrelated chatgpt-agent account exists; no changes made.'
  [[ "$(getent passwd "$account" | cut -d: -f6)" == "$account_home" ]] || fail 'Unexpected account home; no changes made.'
else
  [[ ! -e "$account_home" && ! -L "$account_home" ]] || fail 'The account home already exists; no changes made.'
fi
if [[ -e "$sudo_file" || -L "$sudo_file" ]]; then
  [[ ! -L "$sudo_file" && "$(cat "$sudo_file")" == "$sudo_rule" ]] || fail 'Existing sudo rule differs; no changes made.'
fi

packages=()
command -v sudo >/dev/null || packages+=(sudo)
[[ -x /usr/sbin/sshd ]] || packages+=(openssh-server)
command -v curl >/dev/null || packages+=(curl)
if (( ${#packages[@]} )); then
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${packages[@]}"
fi
/usr/sbin/sshd -t
if ! id "$account" >/dev/null 2>&1; then
  useradd --create-home --home-dir "$account_home" --shell /bin/bash "$account"
  install -d -m 0700 "$marker"
  printf '%s\n' 'Managed dedicated SSH account for this cloud environment.' > "$marker/managed-account"
fi
[[ ! -L "$account_home/.ssh" && ! -L "$account_home/.ssh/authorized_keys" ]] || fail 'Refusing symlinked SSH files.'
install -d -m 0700 -o "$account" -g "$(id -gn "$account")" "$account_home/.ssh"
auth="$account_home/.ssh/authorized_keys"
touch "$auth"
line="restrict $public_key"
if ! grep -Fqx -- "$line" "$auth"; then
  # A leading newline also preserves a pre-existing last line without a newline.
  printf '\n%s\n' "$line" >> "$auth"
fi
chown "$account:$(id -gn "$account")" "$auth"
chmod 0600 "$auth"

rule_temp="$(mktemp)"
trap 'rm -f -- "$rule_temp"' EXIT
printf '%s\n' "$sudo_rule" > "$rule_temp"
visudo -cf "$rule_temp"
install -m 0440 -o root -g root "$rule_temp" "$sudo_file"
visudo -c
systemctl is-active --quiet ssh || systemctl start ssh
printf '%s\n' 'Dedicated SSH account installed with FULL administrator access via sudo.'

if ! command -v tailscale >/dev/null; then
  ts_installer="$(mktemp)"
  curl --fail --location --silent --show-error --proto '=https' --proto-redir '=https' \
    https://tailscale.com/install.sh -o "$ts_installer"
  sh "$ts_installer"
  rm -f -- "$ts_installer"
  printf '%s\n' 'Tailscale installed. Run tailscale up and sign in to your existing account.'
else
  printf '%s\n' 'Existing Tailscale installation preserved. Check tailscale status locally; sign in if needed.'
fi
printf '%s\n' 'After Tailscale is connected, return only the output of these commands:'
printf '%s\n' 'tailscale ip -4' 'hostname' 'cat /etc/ssh/ssh_host_ed25519_key.pub'
printf '%s\n' 'No passwords, private keys, or Tailscale login links are needed in chat.'
