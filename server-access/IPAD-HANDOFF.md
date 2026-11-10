# Move server management to your iPad

These steps prepare terminal access for this cloud environment. **They have not been run on your server yet, and remote access is not verified.** The setup creates a dedicated `chatgpt-agent` account with passwordless `sudo`: that is **full administrator access**. The SSH key's `restrict` option disables forwarding and interactive PTYs; it does not limit administrator privileges.

1. **Check the iPad before leaving the laptop.** Open ChatGPT on the iPad with the same account and this same conversation. Install the official Tailscale iPad app and sign in to your existing Tailscale account. Confirm the iPad can also open the local server Shell in step 2. The laptop is not part of the connection path; once those iPad recovery paths work, the remaining setup can be performed there.

2. **Open the server shell.** While the iPad is on your home Wi-Fi, open `https://192.168.1.223:8006/` in Safari and use your established, verified server login. In Proxmox, select the node → **Shell**. Confirm it is the server's root shell. If this is not Proxmox, stop and tell me the actual server OS. Do not send passwords or private keys to chat.

3. **Paste this entire block into that server Shell.** It saves a temporary script and runs it. It adds only this environment's public SSH key, preserves existing keys and SSH configuration, and installs missing dependencies. The private SSH key stays in the cloud environment. Existing Tailscale preferences are left unchanged.

```bash
chatgpt_setup_file="$(mktemp)" &&
cat > "$chatgpt_setup_file" <<'CHATGPT_SERVER_SETUP'
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
CHATGPT_SERVER_SETUP
bash "$chatgpt_setup_file"
```

If it stops with an error, send the non-secret error text. Do not change SSH settings or reset Tailscale to make it continue. Package installation can stop if the server's configured package repositories require unavailable access.

4. **Connect Tailscale locally.** If the script installed Tailscale for the first time, run `tailscale up` in the server Shell and complete the sign-in link yourself, using the same account as the iPad. If Tailscale was already installed, inspect `tailscale status` locally first. Run enrollment only if login is needed; preserve existing custom preferences and follow any explicit flags the installed client requires. Do not use `--reset`. Never paste Tailscale sign-in links or enrollment keys into chat.

5. **Send only these public identifiers in this conversation.** Run this block in the server Shell and paste the output here. The last command reads the **public** host key, not its private counterpart. This lets me verify the server's identity before logging in.

```sh
tailscale ip -4
hostname
cat /etc/ssh/ssh_host_ed25519_key.pub
```

6. **Connect this cloud environment to the same private network.** In its environment settings, configure the managed Tailscale/VPN integration for the same Tailscale network and enter any required enrollment credential securely there. Review, save, and **Publish**; draft saving alone does not enroll a new VPN. I cannot see the exact VPN field names in this chat. Permit this environment to reach the server on TCP **22** for SSH and **8006** for the web interface in the Tailscale access policy. Older environments may also need a raw TCP destination grant in environment settings: use the exact server DNS name or its Tailscale IPv4 address as a `/32`, rather than a broad network. An HTTP permission alone does not authorize SSH. Tell me when publication finishes; I will recheck the running configuration.

7. **Verify autonomous access before relying on it.** I must successfully run `id`, `hostname`, and `sudo -n true` through SSH, then disconnect and reconnect. You should independently confirm that the iPad can still open this chat and a server shell. Safari with Tailscale can reach the server's verified HTTPS address; a trusted iPad SSH client is another recovery path. A changed address may require a matching server certificate and its public CA; keep certificate verification enabled. An embedded Desktop viewer inside ChatGPT is not promised and is not required for SSH automation. The server and network equipment must stay powered on and connected; the laptop does not need to run.

Access applies to this configured cloud environment, not every ChatGPT conversation. Published filesystem state should retain the protected SSH identity; processes and sessions must reconnect after restart.

To revoke access, use your independent local/server login to remove the exact `restrict ssh-ed25519 … chatgpt-cloud-server-access` key installed by this setup and the dedicated `/etc/sudoers.d/90-chatgpt-agent` grant, after checking their contents. Preserve unrelated keys and sudo rules. Remove the cloud environment's Tailscale access or enrollment through the appropriate settings as well. Do not delete the account's home or unrelated configuration unless separately intended.
