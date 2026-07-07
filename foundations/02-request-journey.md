# 2. The request journey

Consider a browser visiting:

```text
https://example.com/blogs/42/
```

A working request follows this path:

```text
1. Browser asks DNS for example.com.
2. DNS returns an IP address.
3. Browser opens TCP port 443 on that IP.
4. Provider firewall and host firewall decide whether it may enter.
5. Nginx, Apache, or Caddy receives the TLS connection.
6. The web server proves its identity with a certificate and decrypts HTTP.
7. A static request is served directly; a dynamic request is proxied internally.
8. Gunicorn/uWSGI/Uvicorn/Daphne calls Django through WSGI or ASGI.
9. Django resolves URL → view → permissions → database work → response.
10. The response travels back through the same layers.
```

## Why the extra layers are useful

It may look simpler to expose Django directly. Production layers exist because they are specialists:

| Component | Specialist responsibility |
|---|---|
| DNS | Human name to network address |
| Reverse proxy | TLS, redirects, static files, client connection handling, access logs |
| App server | Python worker lifecycle and WSGI/ASGI protocol |
| Django | application rules, forms, ORM, authorization, templates/API |
| PostgreSQL | durable transactions, indexes, concurrent data access |
| systemd | start on boot, restart after failure, service logs |

This division also reduces attack surface. Only ports 80 and 443 should usually be public. The app server can listen on `127.0.0.1` or a Unix socket; PostgreSQL can listen only locally or on a private network.

## A debugging map

| Symptom | Most likely layer | First commands/questions |
|---|---|---|
| Domain cannot be resolved | DNS | `dig example.com`, record/TTL/registrar check |
| Connection timed out | provider firewall/UFW/service | provider network rules, `ufw status`, `systemctl status` |
| Certificate warning | DNS/TLS/vhost | does DNS point to correct server? does certificate include hostname? |
| `502 Bad Gateway` | proxy → app server | is Gunicorn/Uvicorn running? correct bind/socket? proxy error log? |
| `500 Server Error` | Django/DB | `journalctl -u <app-service>`, Django error traceback |
| `404` for only one object | app URL/data query | generated URL, `slug`, date/timezone, filters |
| CSS/JS missing | static config | `collectstatic`, `alias`, permissions, browser network tab |
| CSRF 403 | HTTPS/proxy/settings | current origin, secure cookie, forwarded proto, trusted origins |
| site dies after reboot | systemd | `systemctl is-enabled <service>` |

Do not jump to application code when the network layer is failing, and do not open ports when the issue is a bad URL pattern. Trace the request from the outside inward.
