# 24. Logging, monitoring, and incident response

## Logs are evidence

| Layer | Where to inspect |
|---|---|
| Gunicorn/Uvicorn systemd service | `journalctl -u <APP_NAME>` |
| Nginx | `/var/log/nginx/access.log`, `/var/log/nginx/error.log` or vhost logs |
| Apache | `/var/log/apache2/*access.log`, `*error.log` |
| PostgreSQL | distro/service log or `journalctl -u postgresql` |
| Django application errors | app-server journal/structured error tracking |

## Debug an HTTP 500

1. Reproduce the request once.
2. Follow the application service journal.
3. Read the traceback, not random old log entries.
4. Identify whether configuration, code, database, permissions, or an external dependency failed.
5. Fix locally and add a regression test when practical.
6. Deploy a narrow verified fix.

```bash
sudo journalctl -u <APP_NAME> -f
```

## Debug a 502

A `502 Bad Gateway` typically means the proxy reached its own process but cannot get a valid response from the upstream app server.

Check:

```bash
sudo systemctl status <APP_NAME>
curl -I http://127.0.0.1:8000/
sudo tail -n 100 /var/log/nginx/error.log
```

## Monitoring layers

A useful small-app stack:

- external uptime monitor requests `/healthz/` over HTTPS;
- application error tracking reports uncaught exceptions with release/version metadata;
- system monitoring tracks CPU, memory, disk, service restarts, certificate expiry, backup success;
- database monitoring tracks connections, disk growth, slow queries when needed.

Monitoring does not prevent every failure. It reduces time-to-detection and gives you evidence.

## Incident response outline

```text
1. Detect: monitor/user/log alert.
2. Triage: scope, severity, last deploy, affected endpoint.
3. Contain: stop harmful action or roll back safe code.
4. Recover: restore service/data as needed.
5. Verify: health check + critical flow.
6. Learn: root cause, regression test, runbook/document update.
```

Avoid changing five unrelated variables while debugging. That destroys the evidence needed to understand the actual cause.
