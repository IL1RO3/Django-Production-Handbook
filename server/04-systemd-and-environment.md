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
