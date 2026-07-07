# 14. Nginx + Gunicorn + PostgreSQL

This is the recommended reference stack for a first conventional Django VPS deployment.

```text
Internet → Nginx :80/:443 → Gunicorn 127.0.0.1:8000 → Django → PostgreSQL
```

## Why this stack

Nginx is excellent at public HTTP/TLS, redirects, static file delivery, buffering slow clients, and reverse proxying. Gunicorn focuses on Python workers. PostgreSQL stores application data. Each component has a narrow, understandable job.

## Install Nginx and Certbot

```bash
sudo apt install -y nginx certbot python3-certbot-nginx
sudo systemctl enable --now nginx
```

## HTTP configuration before certificate issuance

```nginx
# /etc/nginx/sites-available/<APP_NAME>
server {
    listen 80;
    listen [::]:80;
    server_name <DOMAIN> <WWW_DOMAIN>;

    location /static/ {
        alias /srv/<APP_NAME>/staticfiles/;
    }

    location /media/ {
        alias /srv/<APP_NAME>/media/;
    }

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Enable and test:

```bash
sudo ln -s /etc/nginx/sites-available/<APP_NAME> /etc/nginx/sites-enabled/<APP_NAME>
sudo nginx -t
sudo systemctl reload nginx
```

## Explain the configuration

| Directive | Meaning |
|---|---|
| `listen 80` | accepts HTTP for certificate validation/initial traffic |
| `server_name` | chooses this server block for matching hostnames |
| `alias` | maps web paths to filesystem directories; trailing slash matters |
| `proxy_pass` | forwards dynamic requests to Gunicorn locally |
| `Host` | preserves the client hostname so Django can apply host checks |
| `X-Forwarded-For` | records original client address chain |
| `X-Forwarded-Proto` | tells Django whether the browser used HTTPS |

## Obtain TLS certificate

Once DNS resolves to this server and port 80 is reachable:

```bash
sudo certbot --nginx -d <DOMAIN> -d <WWW_DOMAIN>
```

Certbot can modify the Nginx configuration to add certificate paths and an HTTP-to-HTTPS redirect. Read the resulting file rather than treating it as magic.

## Final Nginx behavior

After TLS, your HTTP server block should redirect all requests to HTTPS. Your HTTPS server block should continue to serve static/media and proxy dynamic paths.

## Verification

```bash
sudo nginx -t
sudo systemctl status nginx
sudo systemctl status <APP_NAME>
curl -I http://<DOMAIN>
curl -I https://<DOMAIN>
curl -fsS https://<DOMAIN>/healthz/
```

## Common Nginx/Gunicorn problems

- `502 Bad Gateway`: Gunicorn stopped, wrong port, wrong `proxy_pass`, or application crash.
- static `404`: wrong `alias` path or missing `collectstatic`.
- `403`: Nginx lacks directory traversal/read permission, or an app-level CSRF rule is failing.
- redirect loop: `X-Forwarded-Proto` and Django `SECURE_PROXY_SSL_HEADER` disagree.
