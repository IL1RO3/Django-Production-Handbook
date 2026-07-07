# 18. Caddy + Gunicorn

Caddy is a web server and reverse proxy with automatic HTTPS as a central feature.

```text
Internet → Caddy :80/:443 → Gunicorn 127.0.0.1:8000 → Django → PostgreSQL
```

## Why choose Caddy

- concise configuration,
- automatic certificate provisioning and renewal for valid public hostnames,
- automatic HTTP-to-HTTPS redirect behavior in normal cases,
- useful defaults for a small server.

Caddy does not replace Django security settings, database backups, UFW, systemd, or testing.

## Example Caddyfile

```caddyfile
# /etc/caddy/Caddyfile
<DOMAIN>, <WWW_DOMAIN> {
    encode zstd gzip

    handle_path /static/* {
        root * /srv/<APP_NAME>/staticfiles
        file_server
    }

    handle_path /media/* {
        root * /srv/<APP_NAME>/media
        file_server
    }

    reverse_proxy 127.0.0.1:8000 {
        header_up Host {host}
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}
    }
}
```

## Notes

- Caddy must be able to bind ports 80 and 443 and the public DNS record must point to the server.
- `handle_path` strips the matching prefix; use it only when the filesystem root is set for the stripped path. Test static URLs carefully.
- Configure Django proxy awareness only if the proxy sends the required forwarded-proto header.
- Use `caddy validate --config /etc/caddy/Caddyfile` before reloads.

## When not to choose Caddy

Do not pick Caddy only because it has fewer lines of config if your team has established Apache/Nginx processes that are better understood and maintained. Operational familiarity is a real technical advantage.

## Walk through the Caddyfile

```caddyfile
<DOMAIN>, <WWW_DOMAIN> {
```

This site block handles the listed hostnames. Caddy will try to obtain and renew HTTPS certificates for valid public names automatically.

```caddyfile
encode zstd gzip
```

This enables response compression when useful. Compression reduces bandwidth for text responses such as HTML, CSS, and JavaScript.

```caddyfile
handle_path /static/* {
    root * /srv/<APP_NAME>/staticfiles
    file_server
}
```

`handle_path` matches `/static/*` and strips the matched prefix before looking on disk. `root` selects the filesystem directory. `file_server` tells Caddy to serve files directly.

```caddyfile
handle_path /media/* {
    root * /srv/<APP_NAME>/media
    file_server
}
```

This serves local media files. Use this only when local public media is the intended design.

```caddyfile
reverse_proxy 127.0.0.1:8000 {
```

All other requests go to Gunicorn on the private local port. Caddy remains the public edge; Gunicorn remains private.

```caddyfile
header_up Host {host}
header_up X-Real-IP {remote_host}
header_up X-Forwarded-For {remote_host}
header_up X-Forwarded-Proto {scheme}
```

These pass request context to Django. `{host}` is the browser-requested hostname. `{scheme}` is usually `https` after Caddy terminates TLS.

## Caddy operational commands

```bash
sudo caddy validate --config /etc/caddy/Caddyfile
```

Checks config syntax before reload.

```bash
sudo systemctl reload caddy
```

Reloads Caddy after a valid config change.

```bash
sudo journalctl -u caddy -n 100 --no-pager
```

Shows Caddy logs, including certificate and proxy errors.

Caddy is concise, but you still need to understand the path behavior. Most Caddy static-file mistakes come from confusing `handle`, `handle_path`, `root`, and the URL prefix that remains after matching.
