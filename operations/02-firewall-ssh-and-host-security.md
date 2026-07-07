# 25. Firewall, SSH, Fail2Ban, and host security

## UFW baseline

From an existing SSH session, first permit SSH, then web traffic, then enable UFW:

```bash
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable
sudo ufw status numbered
```

Keep the SSH session open and test a second login before declaring success.

Do not mix UFW with a separate hand-managed native nftables ruleset unless you fully understand ownership of the firewall configuration. Choose one clear source of truth.

## Provider firewall

Mirror the same inbound policy at the hosting provider: SSH, HTTP, HTTPS. The provider firewall is an outer boundary; UFW is a host boundary. One does not make the other useless.

## SSH hardening sequence

1. Create and test SSH key login.
2. Create a sudo-capable deploy user.
3. Test another SSH session as that user.
4. Disable root/password SSH login only after the key path is confirmed.
5. Retain console/provider recovery access.

Never apply a hardening recipe blindly while you have only one unverified way back into the server.

## Fail2Ban

Fail2Ban watches logs and temporarily bans repeated suspicious login failures. It is useful friction against basic brute force; it is not a replacement for keys and patched software.

```bash
sudo apt install -y fail2ban
```

Example SSH jail:

```ini
# /etc/fail2ban/jail.d/sshd.local
[sshd]
enabled = true
maxretry = 5
findtime = 10m
bantime = 1h
```

Then:

```bash
sudo systemctl restart fail2ban
sudo fail2ban-client status sshd
```

## Patch management

Apply regular OS/package updates. Before large upgrades, have a backup and maintenance window. Security updates deserve priority, but update discipline includes verification—not just pressing upgrade and disappearing.

## Filesystem and process principles

- app processes run as non-root;
- production secrets are not world-readable;
- code is not edited casually on the server;
- database is private;
- reverse proxy is the only public application entry point;
- logs are reviewed, not ignored;
- backups are off-host;
- file uploads are treated as untrusted input and never executed as server-side code.
