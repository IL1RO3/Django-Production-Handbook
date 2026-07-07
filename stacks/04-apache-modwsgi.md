# 17. Apache + mod_wsgi

`mod_wsgi` is an Apache module that hosts Python WSGI applications. This removes Gunicorn from the architecture:

```text
Internet → Apache + mod_wsgi → Django → PostgreSQL
```

## When it is a good choice

- Apache is already mandatory/standard in the environment.
- Your team has mod_wsgi operational experience.
- You prefer one service family rather than proxying to Gunicorn.

## What makes it harder

`mod_wsgi` is compiled against a Python installation. The Python version and virtual environment must be compatible. This is why Gunicorn is often the lower-friction first choice for a standalone Django VPS.

## Install

```bash
sudo apt install -y apache2 libapache2-mod-wsgi-py3
sudo a2enmod wsgi ssl headers
```

## Daemon-mode configuration

Use daemon mode so Django runs in its own managed Apache daemon group rather than inside generic Apache worker processes.

```apache
# /etc/apache2/sites-available/<APP_NAME>.conf
<VirtualHost *:80>
    ServerName <DOMAIN>

    Alias /static/ /srv/<APP_NAME>/staticfiles/
    <Directory /srv/<APP_NAME>/staticfiles/>
        Require all granted
    </Directory>

    WSGIDaemonProcess <APP_NAME> \
        python-home=/srv/<APP_NAME>/venv \
        python-path=/srv/<APP_NAME>/app \
        processes=2 threads=15
    WSGIProcessGroup <APP_NAME>
    WSGIScriptAlias / /srv/<APP_NAME>/app/<PROJECT_PACKAGE>/wsgi.py

    <Directory /srv/<APP_NAME>/app/<PROJECT_PACKAGE>>
        <Files wsgi.py>
            Require all granted
        </Files>
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/<APP_NAME>-error.log
    CustomLog ${APACHE_LOG_DIR}/<APP_NAME>-access.log combined
</VirtualHost>
```

## Important notes

- Confirm the installed `mod_wsgi` matches your Python major/minor version.
- Make code readable/traversable by the Apache/mod_wsgi daemon user.
- Static files should still be served by Apache, not Django.
- Use `collectstatic` and private environment variables exactly as you would with Gunicorn.
- Use Certbot and the same UFW model: only 22/80/443 public.

## Select this on purpose

Do not treat mod_wsgi as automatically “more native” or Gunicorn as automatically “more modern.” Both are valid WSGI approaches. Pick the one your operational model can support confidently.
