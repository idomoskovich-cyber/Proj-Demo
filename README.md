# Server access from your iPad

Start with the [iPad handoff guide](server-access/IPAD-HANDOFF.md). It contains the complete block to paste into the Proxmox node Shell.

- [Last two assistant messages](server-access/LAST-TWO-MESSAGES.md)
- [Private server access guide](server-access/README.md)
- [Server setup script](server-access/setup-server.sh)
- [Saved cloud startup instructions](server-access/STARTUP-INSTRUCTIONS.md)
- [Cloud installation script](server-access/install-cloud.sh)
- [SSH connection helper](server-access/ssh-command.sh)
- [HTTPS connectivity checker](server-access/check-access.py)
- [Verified socat installer](server-access/ensure-socat.sh)
- [Public SSH key](server-access/ssh/id_ed25519.pub)

## Current status

Prepared on November 10, 2026. Cloud tools and a dedicated SSH identity are prepared. The server bootstrap has **not** been run on the server. Managed VPN enrollment, SSH access, authenticated server management, and iPad handoff are **not verified yet**. Saving these files to GitHub does not connect the server or publish the cloud environment.

The setup grants the dedicated server account full administrator access through passwordless sudo. Review the guide before running its server-side block.

## What stays in the cloud environment

The private SSH key, runtime cache, binaries, and live sessions are excluded. The public key in this repository is tied to the private key retained in the original cloud environment. Cloning this repository alone cannot recreate that SSH identity or restore access. Continue in the same configured cloud environment; preserve its identity when publishing.

The cloud helper scripts use `/workspace/server-access`, managed proxy `proxy:8088`, and the environment's Tailscale integration. They are for that cloud environment, not commands to run on the iPad or the Proxmox server. Only the clearly marked server bootstrap belongs in the Proxmox node Shell. After cloning, preserve the original `/workspace/server-access` directory and its private key; do not replace it wholesale.

The laptop is not part of the intended connection path. Keep the server and network equipment powered on, and confirm an independent iPad server-shell recovery path before relying on remote automation.
