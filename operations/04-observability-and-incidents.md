# 27. Logging, monitoring, and incident response

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

## Structured application logging

Plain tracebacks are useful, but production logs should also answer operational questions. Include request ID, release version, user/account identifier when safe, endpoint, status code, latency, and external dependency name. Never log passwords, tokens, session cookies, full credit-card data, or private payloads.

A practical flow is:

```text
request enters proxy
  -> request ID is assigned or preserved
  -> Django includes it in logs/errors
  -> error tracker links traceback to release
  -> deployment history shows what changed
```

## Metrics, alerts, and dashboards

Metrics are numeric signals over time. Alerts are rules that notify a human when a signal needs action. Dashboards are for investigation; they are not a substitute for alerts.

Useful starter alerts:

| Alert | Why it matters |
|---|---|
| HTTPS health check fails | users may not reach the app |
| repeated 5xx responses | app or dependency is failing |
| disk usage above threshold | logs/uploads/database can stop the server |
| certificate expires soon | HTTPS outage is predictable and preventable |
| backup job failed | recovery point objective is at risk |
| service restart loop | systemd is keeping a broken process alive |
| database connection exhaustion | requests may fail even while CPU looks fine |

## Tool choices

Common options:

| Tool | Typical use |
|---|---|
| Sentry | Django exception tracking, releases, performance samples |
| UptimeRobot/Better Stack/Pingdom | external uptime checks |
| Prometheus | metrics collection and alert rules |
| Grafana | metrics dashboards |
| Netdata | quick host-level visibility |
| systemd journal | first source for service logs on a VPS |

Use managed tools when they reduce operational load. Self-host monitoring only when you can also monitor, back up, upgrade, and secure the monitoring system.

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

## Post-incident review

After recovery, write a short review while the evidence is fresh:

- impact window and affected users;
- triggering change or external event;
- detection source;
- what worked during response;
- what slowed response;
- permanent fixes, tests, alerts, or docs to add;
- owner and due date for each follow-up.

The point is not blame. The point is to make the next failure smaller, faster to detect, or easier to recover from.
