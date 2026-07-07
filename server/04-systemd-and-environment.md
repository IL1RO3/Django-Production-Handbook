# 13. systemd and environment files

`systemd` is the service manager on modern Ubuntu. It starts services at boot, restarts failed services according to policy, records journal logs, and provides a stable operational interface.

## Why not `nohup gunicorn ... &`?

A background shell process has no structured restart policy, weak logging, unclear ownership, and does not reliably survive reboots. systemd makes the process an explicit system service.

## Environment file pattern

```ini
# /etc/<APP_NAME>/<APP_NAME>.env
DJANGO_SECRET_KEY='...'
DJANGO_DEBUG=False
POSTGRES_DB=<DB_NAME>
POSTGRES_USER=<DB_USER>
POSTGRES_PASSWORD='...'
```

A systemd service can load it with:

```ini
EnvironmentFile=/etc/<APP_NAME>/<APP_NAME>.env
```

This is not encrypted storage. Its safety comes from permissions and host access control. A secret manager can replace it later, but a permission-controlled environment file is a useful small-VPS baseline.

## Service lifecycle commands

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now <APP_NAME>
sudo systemctl restart <APP_NAME>
sudo systemctl status <APP_NAME>
sudo journalctl -u <APP_NAME> -n 100 --no-pager
sudo journalctl -u <APP_NAME> -f
```

## Important service design rules

- Run the service as `<APP_USER>`, never root.
- Set `WorkingDirectory` so relative paths behave predictably.
- Use absolute executable paths (`/srv/.../venv/bin/gunicorn`).
- Keep application port/socket private.
- Use `Restart=on-failure` for resilience, not to hide a persistent crash.
- Use `systemctl status` and the journal to understand failure before repeatedly restarting.

## What systemd is doing for you

When you create `/etc/systemd/system/<APP_NAME>.service`, you are teaching the operating system how to run your app. Instead of depending on a terminal window, systemd becomes responsible for the process.

It handles:

- starting the app at boot;
- restarting it when it crashes if policy allows;
- attaching logs to the system journal;
- running the process as the correct Linux user;
- ordering startup after basic dependencies such as networking;
- giving operators one consistent command interface.

## Explain the lifecycle commands

```bash
sudo systemctl daemon-reload
```

Systemd does not reread every unit file on every command. After adding or editing a `.service` file, `daemon-reload` tells systemd to reload unit definitions from disk.

```bash
sudo systemctl enable --now <APP_NAME>
```

`enable` means "start this service automatically at boot." `--now` means "also start it immediately." Without `--now`, the service may be enabled for the next reboot but not running yet.

```bash
sudo systemctl restart <APP_NAME>
```

This stops and starts the service. Use it after code or environment changes that require a fresh Python process.

```bash
sudo systemctl status <APP_NAME>
```

This shows whether systemd thinks the service is active, failed, restarting, or disabled. It also shows the main process ID and recent log lines.

```bash
sudo journalctl -u <APP_NAME> -n 100 --no-pager
```

This reads the last 100 journal lines for that service. `--no-pager` prints directly to the terminal, which is easier to copy into notes.

```bash
sudo journalctl -u <APP_NAME> -f
```

This follows new logs live. Use it in one terminal while making a request from another terminal or browser.

## Reading a service failure

If a service fails, do not immediately change random settings. Read the first real error. Common examples:

| Log clue | Likely meaning |
|---|---|
| `KeyError: 'DJANGO_SECRET_KEY'` | environment file is missing a required variable |
| `ModuleNotFoundError` | wrong virtualenv, missing dependency, or wrong project package name |
| `permission denied` | service user cannot read code, env file, socket, static, or media path |
| `could not connect to server` | PostgreSQL is down, private address is wrong, or credentials are wrong |
| `Address already in use` | another process is already bound to that port/socket |

The log is evidence. Preserve it while you debug.
