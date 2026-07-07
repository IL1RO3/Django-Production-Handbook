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

## Walk through the mod_wsgi directives

```apache
WSGIDaemonProcess <APP_NAME> \
    python-home=/srv/<APP_NAME>/venv \
    python-path=/srv/<APP_NAME>/app \
    processes=2 threads=15
```

This creates a named daemon process group for the Django app. `python-home` points to the virtual environment. `python-path` points to the Django project code. `processes=2` starts two daemon processes. `threads=15` allows each process to handle multiple threaded requests.

More processes and threads are not automatically better. Each process uses memory, and threaded code must be safe with shared in-process state. Start modestly and measure.

```apache
WSGIProcessGroup <APP_NAME>
```

This tells Apache that requests for this virtual host should run in the daemon group created above, not in the generic Apache process pool.

```apache
WSGIScriptAlias / /srv/<APP_NAME>/app/<PROJECT_PACKAGE>/wsgi.py
```

This maps the URL root `/` to Django's WSGI entrypoint file. Apache imports that file through mod_wsgi and calls the WSGI application object inside it.

```apache
<Directory /srv/<APP_NAME>/app/<PROJECT_PACKAGE>>
    <Files wsgi.py>
        Require all granted
    </Files>
</Directory>
```

Apache needs explicit permission to access the WSGI file. This does not mean every project file becomes public; it allows Apache/mod_wsgi to load the entrypoint.

## How environment variables work with mod_wsgi

A Gunicorn systemd service usually reads `EnvironmentFile=/etc/<APP_NAME>/<APP_NAME>.env`. With mod_wsgi, Apache is hosting Python, so environment handling is different. Common options are:

- set variables in Apache config with `SetEnv`, then load them in `wsgi.py` when appropriate;
- use a small environment-loading package in Django settings;
- keep secrets in a root-owned file and load it carefully before Django settings need them.

Do not assume the shell environment you see over SSH is visible to Apache. Service managers start processes with their own environment.

## Debugging mod_wsgi startup

If the app fails under mod_wsgi but works locally, check:

1. Apache error log for Python traceback;
2. Python version used by mod_wsgi;
3. virtualenv path in `python-home`;
4. project path in `python-path`;
5. file permissions for Apache/mod_wsgi user;
6. missing environment variables;
7. imports that depend on the current working directory.

mod_wsgi is reliable when configured correctly, but the Python/runtime coupling is stricter than the Gunicorn systemd model.
