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

## What the first package commands do

```bash
sudo apt update
```

This downloads the latest package index from Ubuntu repositories. It does not upgrade software by itself; it refreshes the server's knowledge of available versions.

```bash
sudo apt upgrade
```

This applies available upgrades. On a new server, run it early so you are not building on stale packages.

```bash
sudo apt install -y git curl ca-certificates build-essential python3 python3-venv python3-pip
```

This installs the basic tools the deployment needs:

| Package | Why it is installed |
|---|---|
| `git` | downloads and updates your source code |
| `curl` | tests HTTP endpoints from the terminal |
| `ca-certificates` | lets tools trust public HTTPS certificates |
| `build-essential` | compiles Python packages that need native extensions |
| `python3` | runs Python |
| `python3-venv` | creates an isolated virtual environment |
| `python3-pip` | installs Python packages |

The `-y` flag answers yes to the install prompt. Use it only when you understand the package list.

## Why there are two Linux users

A common beginner mistake is to run everything as `root` because it avoids permission errors. That works until a bug, stolen key, or bad command has unlimited power.

This guide separates identities:

| Identity | Job | Should it log in by SSH? |
|---|---|---|
| `<DEPLOY_USER>` | human deploys code and runs admin commands with sudo | yes |
| `<APP_USER>` | systemd runs Django/Gunicorn with limited permissions | no |
| `www-data` | Nginx/Apache reads public files | no |
| `postgres` | PostgreSQL administration role on the OS | no normal app login |

The app user should be able to read code and write only what the app truly needs, such as local media if you use local media storage. It should not own your whole server.

## Understanding the `install -d` directory commands

```bash
sudo install -d -o <DEPLOY_USER> -g <APP_USER> -m 750 /srv/<APP_NAME>/app
```

Read it piece by piece:

| Piece | Meaning |
|---|---|
| `sudo` | run with administrator privileges |
| `install -d` | create a directory with exact ownership and permissions |
| `-o <DEPLOY_USER>` | make the deploy user the owner |
| `-g <APP_USER>` | make the app user group the group owner |
| `-m 750` | owner can read/write/enter; group can read/enter; others get no access |
| `/srv/<APP_NAME>/app` | the target directory for the application repository |

This is more precise than `mkdir` followed by several `chown` and `chmod` commands.

## Why `g+rX` is used for code

```bash
sudo chmod -R g+rX /srv/<APP_NAME>/app
```

`g+rX` means "give the group read permission, and give execute permission only to directories and already-executable files." Directories need execute permission so a process can enter them. Normal Python files need read permission, not execute permission.

This lets `<APP_USER>` import Python code without making every file executable.
