# 11. SSH, users, permissions, and directories

## First login baseline

```bash
sudo apt update
sudo apt upgrade
sudo apt install -y git curl ca-certificates build-essential python3 python3-venv python3-pip
```

Do not apply a firewall lockout from a fragile connection. Keep one working SSH session open while testing another.

## Use SSH keys before disabling passwords

On your local machine:

```bash
ssh-keygen -t ed25519 -C "your-email@example.com"
ssh-copy-id <DEPLOY_USER>@<SERVER_IP>
```

Test a second SSH login using the key. Only then consider hardening `/etc/ssh/sshd_config.d/99-hardening.conf`:

```text
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
```

Validate and reload carefully:

```bash
sudo sshd -t
sudo systemctl reload ssh
```

Do not close the original session until a fresh key-based session succeeds.

## Create identities

```bash
sudo adduser <DEPLOY_USER>
sudo usermod -aG sudo <DEPLOY_USER>

sudo adduser --system --group --home /srv/<APP_NAME> --shell /usr/sbin/nologin <APP_USER>
```

`<DEPLOY_USER>` is a human/operator account. `<APP_USER>` is a non-login service identity that runs the Python application.

## Create directories

```bash
sudo install -d -o <DEPLOY_USER> -g <APP_USER> -m 750 /srv/<APP_NAME>
sudo install -d -o <DEPLOY_USER> -g <APP_USER> -m 750 /srv/<APP_NAME>/app
sudo install -d -o <APP_USER> -g www-data -m 2750 /srv/<APP_NAME>/staticfiles
sudo install -d -o <APP_USER> -g www-data -m 2750 /srv/<APP_NAME>/media
```

The setgid bit in `2750` helps new files inherit the directory group. Adjust only based on actual access needs.

## Understand permissions

For `750`:

```text
owner: read/write/enter
 group: read/enter
other: no access
```

Files containing secrets should commonly be `640` or stricter. Runtime files should not be world-writable. Avoid `chmod 777`; it hides an ownership design problem rather than solving it.

## Clone application code

Run Git as the deploy user, not root:

```bash
sudo -u <DEPLOY_USER> -H bash -lc '
cd /srv/<APP_NAME>
git clone <REPOSITORY_URL> app
python3 -m venv /srv/<APP_NAME>/venv
/srv/<APP_NAME>/venv/bin/pip install --upgrade pip
/srv/<APP_NAME>/venv/bin/pip install -r app/requirements.txt
'
```

Then grant the app service read/execute access to code without making it the repository owner:

```bash
sudo chgrp -R <APP_USER> /srv/<APP_NAME>/app
sudo chmod -R g+rX /srv/<APP_NAME>/app
```

Adapt this rule if your deployment user needs to keep exclusive ownership; the principle is that application code should be readable by the runtime user, while Git operations remain controlled.
