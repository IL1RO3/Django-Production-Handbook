# 22. Build, run, and multi-stage images

A Dockerfile is only useful once you can build it into an image, run it as a container, and inspect what happened. This chapter covers the everyday commands and the multi-stage technique that shrinks production images.

## Build an image

```bash
docker build -t <APP_NAME>:0.1.0 .
```

- `-t <APP_NAME>:0.1.0` tags the image with a name and version.
- `.` is the **build context**, the directory Docker sends to the daemon and the root that `COPY` paths are relative to.

Run the build from the repository root, where the `Dockerfile` and `.dockerignore` live.

### Useful build flags

| Flag | Effect |
|---|---|
| `-t, --tag` | name the image (repeatable for multiple tags) |
| `--no-cache` | rebuild every layer, ignoring the cache |
| `--pull` | fetch a fresh copy of the base image |
| `--progress=plain` | show plain output instead of the fancy progress UI |

## Inspect images

```bash
docker images
docker image ls <APP_NAME>
docker image history <APP_NAME>:0.1.0
docker image inspect <APP_NAME>:0.1.0
```

`docker image history` shows each layer and its size, which is how you find a bloated layer. `docker image inspect` shows the metadata, including the configured `Cmd`, `Env`, and `User`.

## Run a container

```bash
docker run --rm -p 8000:8000 --env-file .env <APP_NAME>:0.1.0
```

| Flag | Effect |
|---|---|
| `--rm` | delete the container when it stops (useful for testing) |
| `-p 8000:8000` | publish host port 8000 to container port 8000 |
| `--env-file .env` | load environment variables from a file into the container |
| `--name <name>` | give the container a stable name |
| `-d` | run detached in the background |
| `-it` | run interactively with a TTY |

The port mapping syntax is `host:container`. Publishing `8000:8000` makes the container reachable on your machine's port 8000. **Do not publish the PostgreSQL or Redis port** in production; those services should stay on the private container network.

## Run commands inside a container

`docker run` starts the image's default command. To run a different command instead, either pass it after the image name or use `docker exec` on an already-running container:

```bash
# Run a one-off container for a management command.
docker run --rm --env-file .env <APP_NAME>:0.1.0 python manage.py migrate

# Open a shell in a running container.
docker exec -it <APP_NAME>_web_1 bash
```

Typical tasks that run as one-off containers or `exec` commands:

```bash
python manage.py migrate
python manage.py collectstatic --noinput
python manage.py createsuperuser
python manage.py check --deploy
```

These are the same Django commands you already know, executed inside the container's environment.

## See logs and state

```bash
docker ps                       # running containers
docker ps -a                    # all containers, including stopped ones
docker logs <container>         # print stdout/stderr
docker logs -f <container>      # follow logs live
docker stop <container>         # graceful stop (SIGTERM, then SIGKILL)
docker rm <container>           # delete a stopped container
```

`docker ps` shows each container's image, status, and published ports. If a container exits immediately, `docker logs` usually explains why (for example a missing environment variable or a bad `ALLOWED_HOSTS`).

## Layer caching in practice

Docker caches each layer keyed on the instruction and its inputs. The classic mistake is:

```dockerfile
COPY . .
RUN pip install -r requirements.txt
```

Every code change invalidates `COPY . .`, so the following `RUN pip install` reruns on every build. The correct order installs dependencies first:

```dockerfile
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
```

Now `pip install` only reruns when `requirements.txt` changes.

## Tagging and versioning

Never deploy a bare `latest` tag and never rely on it meaning "newest". Give each build a specific version and, when you are ready, also tag it as the current release:

```bash
docker build -t <APP_NAME>:0.1.0 .
docker tag <APP_NAME>:0.1.0 <APP_NAME>:latest
```

Specific tags make rollback possible: you can always run or redeploy the exact image that worked yesterday.

## Multi-stage builds

A multi-stage build uses more than one `FROM` instruction. The early stages prepare artifacts; the final stage copies only what it needs. This leaves compilers and build tools out of the shipped image.

```dockerfile
# ---- Stage 1: builder ----
FROM python:3.13-slim AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential libpq-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip wheel --no-cache-dir --wheel-dir /wheels -r requirements.txt

# ---- Stage 2: runtime ----
FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Only the runtime library, not the compiler toolchain.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libpq5 \
    && rm -rf /var/lib/apt/lists/*

RUN addgroup --system app && adduser --system --ingroup app app

COPY --from=builder /wheels /wheels
RUN pip install --no-cache-dir --no-index --find-links=/wheels /wheels/*.whl \
    && rm -rf /wheels

COPY . .

RUN mkdir -p /app/staticfiles /app/media && chown -R app:app /app

USER app

EXPOSE 8000

CMD ["gunicorn", "<PROJECT_PACKAGE>.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "3"]
```

How it works:

1. The `builder` stage installs the compiler toolchain, then runs `pip wheel` to build `.whl` files into `/wheels`.
2. The `runtime` stage installs only `libpq5` (the shared library), copies the wheels, and installs them with `--no-index --find-links=/wheels` so pip cannot reach the network.
3. `COPY --from=builder /wheels /wheels` copies artifacts from the named stage. The builder stage is discarded when the build finishes.

The result is a smaller image without `gcc`, headers, or the wheel cache. When you use `psycopg[binary]` and have no packages that compile C extensions, a multi-stage build saves less, and the single-stage Dockerfile from the previous chapter is perfectly fine. Use multi-stage when your dependencies require compiling.

## Debugging a build

- `docker build --progress=plain --no-cache .` shows every layer and its output without the progress UI.
- If a `RUN` step fails, its output is printed. The usual causes are a missing system package, a network/proxy problem, or a Python package that cannot compile.
- If the image builds but the container exits, inspect it with `docker logs` and `docker inspect`, or override the command to get a shell: `docker run --rm -it <image> bash`.

## Next

A single container is not enough for a Django application with a database. [Docker Compose](docker-compose-from-zero.md) describes the whole multi-service topology in one file.
