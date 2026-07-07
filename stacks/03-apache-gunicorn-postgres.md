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
