# 16. Apache + Gunicorn + PostgreSQL

Use this stack when Apache is already your web-server standard or you prefer its virtual-host/module ecosystem.

```text
Internet → Apache :80/:443 → Gunicorn 127.0.0.1:8000 → Django → PostgreSQL
```

## Install modules

```bash
sudo apt install -y apache2 certbot python3-certbot-apache
sudo a2enmod proxy proxy_http headers ssl rewrite
sudo systemctl enable --now apache2
```

## HTTP virtual host before TLS

```apache
# /etc/apache2/sites-available/<APP_NAME>.conf
<VirtualHost *:80>
    ServerName <DOMAIN>
    ServerAlias <WWW_DOMAIN>

    Alias /static/ /srv/<APP_NAME>/staticfiles/
    <Directory /srv/<APP_NAME>/staticfiles/>
        Require all granted
    </Directory>

    Alias /media/ /srv/<APP_NAME>/media/
    <Directory /srv/<APP_NAME>/media/>
        Require all granted
    </Directory>

    ProxyPreserveHost On
    RequestHeader set X-Forwarded-Proto "http"
    ProxyPass /static/ !
    ProxyPass /media/ !
    ProxyPass / http://127.0.0.1:8000/
    ProxyPassReverse / http://127.0.0.1:8000/

    ErrorLog ${APACHE_LOG_DIR}/<APP_NAME>-error.log
    CustomLog ${APACHE_LOG_DIR}/<APP_NAME>-access.log combined
</VirtualHost>
```

Enable and test:

```bash
sudo a2ensite <APP_NAME>.conf
sudo a2dissite 000-default.conf
sudo apache2ctl configtest
sudo systemctl reload apache2
```

## TLS

```bash
sudo certbot --apache -d <DOMAIN> -d <WWW_DOMAIN>
```

After Certbot creates/enables the TLS virtual host, ensure the HTTPS vhost sends:

```apache
RequestHeader set X-Forwarded-Proto "https"
```

and preserves `ProxyPreserveHost On`. Django can then be configured with `SECURE_PROXY_SSL_HEADER` when appropriate.

## Why Apache + Gunicorn instead of mod_wsgi?

This keeps Python process management separate from the web server. Gunicorn is easy to run under systemd, restart, and inspect through its own journal. Choose mod_wsgi when you specifically want Apache to host WSGI directly and understand its Python/virtualenv compatibility requirements.

## Verification

```bash
sudo apache2ctl configtest
sudo systemctl status apache2
sudo journalctl -u <APP_NAME> -n 100 --no-pager
sudo tail -n 100 /var/log/apache2/<APP_NAME>-error.log
```

## Walk through the Apache virtual host slowly

```apache
<VirtualHost *:80>
```

This begins an Apache virtual host that listens for HTTP traffic on port 80. The `*` means Apache can accept the request on any local IP address assigned to the server.

```apache
ServerName <DOMAIN>
ServerAlias <WWW_DOMAIN>
```

`ServerName` is the primary hostname for this site. `ServerAlias` lists additional names that should use the same configuration. These should match DNS records, certificate names, and Django `ALLOWED_HOSTS`.

```apache
Alias /static/ /srv/<APP_NAME>/staticfiles/
<Directory /srv/<APP_NAME>/staticfiles/>
    Require all granted
</Directory>
```

`Alias` maps the browser path `/static/` to a real filesystem directory. The matching `<Directory>` block gives Apache permission to serve files from that directory. Without `Require all granted`, Apache may know where the files are but still refuse access.

```apache
Alias /media/ /srv/<APP_NAME>/media/
```

This serves local user uploads. If media files are private, sensitive, or stored in object storage, do not expose this path blindly. Public media and private media need different designs.

```apache
ProxyPreserveHost On
```

This tells Apache to pass the original `Host` header to Gunicorn. Django needs the real host for `ALLOWED_HOSTS`, redirects, CSRF behavior, and absolute URL generation.

```apache
RequestHeader set X-Forwarded-Proto "http"
```

This sets a header that tells Django what protocol the browser used at the public edge. In the HTTP vhost it is `http`; in the HTTPS vhost it should be `https`.

```apache
ProxyPass /static/ !
ProxyPass /media/ !
```

The exclamation mark means "do not proxy this path." Apache should serve static and media files itself instead of sending them to Gunicorn.

```apache
ProxyPass / http://127.0.0.1:8000/
ProxyPassReverse / http://127.0.0.1:8000/
```

`ProxyPass` forwards dynamic requests to Gunicorn on the private loopback port. `ProxyPassReverse` rewrites certain upstream response headers, such as redirects, so the client sees the public site address rather than the private backend address.

```apache
ErrorLog ${APACHE_LOG_DIR}/<APP_NAME>-error.log
CustomLog ${APACHE_LOG_DIR}/<APP_NAME>-access.log combined
```

These create per-site logs. Error logs help debug Apache/proxy/static issues. Access logs show request paths, status codes, client IPs, and timing depending on the log format.

## Explain the Apache commands

```bash
sudo a2enmod proxy proxy_http headers ssl rewrite
```

`a2enmod` enables Apache modules. `proxy` and `proxy_http` support reverse proxying to Gunicorn. `headers` lets Apache set forwarded headers. `ssl` supports HTTPS. `rewrite` is commonly used by Certbot or redirect rules.

```bash
sudo a2ensite <APP_NAME>.conf
```

This enables the site by creating the right symlink from `sites-available` to `sites-enabled`.

```bash
sudo apache2ctl configtest
```

This checks Apache syntax before reload. Run it before every Apache reload.

```bash
sudo systemctl reload apache2
```

Reload asks Apache to reread configuration without a full stop/start when possible. If config syntax is broken, do not reload until it is fixed.

## What Apache is responsible for in this stack

Apache plays the same public-edge role that Nginx plays in the reference stack. It should handle HTTP/TLS, static files, public media if applicable, proxying to Gunicorn, request headers, and access/error logs.

Gunicorn still owns Python worker management. PostgreSQL still owns durable relational data. Keeping those responsibilities separate makes debugging easier.

## Apache request path

```text
browser
  -> Apache virtual host selected by ServerName/ServerAlias
  -> Alias serves /static/ or /media/ from disk
  -> ProxyPass sends dynamic requests to Gunicorn
  -> Gunicorn runs Django WSGI app
  -> Django queries PostgreSQL
```

If Apache returns a 404 for a static file, inspect Apache `Alias` and filesystem paths. If Apache returns 502/503, inspect the Gunicorn service. If Django returns 500, inspect the app journal and Django traceback.

## Apache module mental model

Apache features are often modules. The config only works when the required modules are enabled:

| Module | Why this stack needs it |
|---|---|
| `proxy` | base proxy capability |
| `proxy_http` | proxy HTTP requests to Gunicorn |
| `headers` | set `X-Forwarded-Proto` and similar headers |
| `ssl` | serve HTTPS |
| `rewrite` | redirects and Certbot-managed rules |

If Apache says a directive is invalid, the module that provides that directive may not be enabled.
