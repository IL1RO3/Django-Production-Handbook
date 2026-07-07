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
