# 21. Your first Dockerfile for Django

A **Dockerfile** is a text file named `Dockerfile` (no extension) that describes how to build an image. It lives in the repository root, next to `manage.py`. This chapter explains each instruction by building a working Django image from zero.

## A minimal starting point

```dockerfile
FROM python:3.13-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .

CMD ["gunicorn", "<PROJECT_PACKAGE>.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "3"]
```

This is already a valid image. It is not production-ready yet, but it shows the shape. Let us explain each line.

## The instructions line by line

### `FROM`

```dockerfile
FROM python:3.13-slim
```

`FROM` chooses the base image every other instruction builds on top of. Use the official `python` image and pin a specific version, for example `python:3.13-slim`. Do not use `python:latest`: a floating tag can change the meaning of your build overnight.

- `python:3.13-slim` is a smaller Debian-based image without compilers and documentation. Prefer it for Django.
- `python:3.13-alpine` is even smaller but uses musl libc, which can cause subtle problems with compiled Python packages. It is rarely worth the trouble for Django.
- `python:3.13` (no suffix) includes the full Debian toolchain and is much larger. Use it only if you genuinely need it.

### `WORKDIR`

```dockerfile
WORKDIR /app
```

`WORKDIR` sets the working directory for all following `RUN`, `COPY`, `CMD`, and `ENTRYPOINT` instructions. It also creates the directory if it does not exist. Use an absolute path, not a relative one.

### `ENV`

```dockerfile
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
```

These two environment variables make Python behave better inside a container:

- `PYTHONDONTWRITEBYTECODE=1` stops Python from writing `.pyc` files, which keeps the image smaller.
- `PYTHONUNBUFFERED=1` makes Python print logs immediately instead of buffering them, so `docker logs` shows output in real time.

### `COPY`

```dockerfile
COPY requirements.txt .
COPY . .
```

`COPY <source> <destination>` copies files from the **build context** (the directory you pass to `docker build`) into the image. Prefer `COPY` over `ADD`; `ADD` has extra behavior for archives and URLs that you almost never need.

Copy `requirements.txt` first and install dependencies before copying the rest of the code. This keeps the expensive `pip install` layer cached while you iterate on application code.

### `RUN`

```dockerfile
RUN pip install -r requirements.txt
```

`RUN` executes a command during the build and records the result as a new layer. This is where dependencies are installed, not where the application is started.

### `CMD`

```dockerfile
CMD ["gunicorn", "<PROJECT_PACKAGE>.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "3"]
```

`CMD` defines the default command to run when a container starts. The `["..."]` (exec) form is preferred because it avoids invoking a shell and does not mangle arguments or signals.

Inside a container, Gunicorn must bind to `0.0.0.0`, not `127.0.0.1`. Binding to `0.0.0.0` means "listen on all interfaces **inside this container**"; it does not publish the port to the public internet. Port publishing is a separate `docker run -p` or Compose `ports` decision.

## `CMD` versus `ENTRYPOINT`

| Instruction | Purpose | Overridable? |
|---|---|---|
| `ENTRYPOINT` | the fixed program to run (for example an entrypoint script) | no, without `--entrypoint` |
| `CMD` | default arguments/command, often the server itself | yes, `docker run <image> <command>` overrides it |

For a first Django image, `CMD` alone is enough. Advanced setups use an `ENTRYPOINT` script that waits for the database, runs migrations, then `exec`s the server.

## The `.dockerignore` file

By default `docker build` sends the entire build context to the Docker daemon. If your repository contains a `.git` directory, a `venv/`, uploaded `media/` files, or a `.env` file, all of it is transmitted and can be copied into the image.

A `.dockerignore` file in the project root excludes files from the context, exactly like `.gitignore` excludes files from Git:

```text
.git
.venv/
venv/
__pycache__/
*.pyc
.env
.env.*
staticfiles/
media/
docs/
Dockerfile
.dockerignore
```

Two rules matter most:

1. **Never copy `.env` or any real secret into the image.** A secret baked into a layer is hard to remove and easy to leak through a registry.
2. **Exclude generated data** (`staticfiles/`, `media/`) that is created by `collectstatic` or uploaded at runtime. It belongs in a volume or in object storage, not in the image.

A ready-to-adapt template is in [`config-examples/dockerignore.example`](../config-examples/dockerignore.example); copy it to `.dockerignore` in your project root. The template omits the leading dot so documentation tools can serve it.

## Dependencies: the PostgreSQL driver question

Django needs a PostgreSQL driver installed in the image. The modern choice is **psycopg 3**:

```text
# requirements.txt
Django==5.2.*
gunicorn==23.*
psycopg[binary]==3.2.*
```

`psycopg[binary]` bundles its own copy of `libpq`, so you do **not** need to install `build-essential` and `libpq-dev` into the image. This keeps the Dockerfile simple.

If you instead use `psycopg2` (source build) or `psycopg2-binary`, you must install the matching system packages first:

```dockerfile
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential libpq-dev \
    && rm -rf /var/lib/apt/lists/*
```

Prefer `psycopg[binary]` for a first deployment and move to a source build later if your environment requires it. Always pin versions in `requirements.txt`.

## Running as a non-root user

By default a container's main process runs as **root**. If an attacker escapes the Python process, being root inside the container makes privilege escalation to the host far easier.

Create a dedicated user and switch to it:

```dockerfile
RUN addgroup --system app \
    && adduser --system --ingroup app app \
    && mkdir -p /app/staticfiles /app/media \
    && chown -R app:app /app

USER app
```

The `--system` flags create a user without a password and without a home directory, which is what you want for a service account. Give it ownership only of the directories the app must write to (such as `staticfiles` and `media`), not the whole filesystem.

## The complete first Dockerfile

Putting it together:

```dockerfile
FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

COPY requirements.txt .
RUN pip install --upgrade pip && pip install -r requirements.txt

COPY . .

RUN addgroup --system app \
    && adduser --system --ingroup app app \
    && mkdir -p /app/staticfiles /app/media \
    && chown -R app:app /app

USER app

EXPOSE 8000

CMD ["gunicorn", "<PROJECT_PACKAGE>.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "3"]
```

`EXPOSE 8000` documents the port but does not publish it. `PIP_NO_CACHE_DIR=1` prevents pip from caching into the image, saving space.

This file is available as [`config-examples/Dockerfile`](../config-examples/Dockerfile). In the next chapter you will build it, run it, and then reduce it further with a multi-stage build.
