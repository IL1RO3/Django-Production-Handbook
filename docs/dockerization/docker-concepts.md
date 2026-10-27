# 20. Docker fundamentals: images, containers, and layers

Docker packages an application and everything it needs to run into a portable unit called an **image**. A running copy of that image is a **container**. This chapter explains those ideas from zero, so the Dockerfile and Compose chapters that follow make sense.

## Why Docker exists

A Django project on your laptop works because of a long chain of assumptions: a specific Python version, a virtual environment, system packages such as `libpq`, environment variables, and a particular directory layout. When the same code runs on another machine, any difference in that chain can break it.

Docker turns that chain into a **build recipe** (the Dockerfile) that produces a **portable image**. The image contains the operating system libraries, Python interpreter, dependencies, and your code. Containers run from that image with a predictable, isolated filesystem, network, and process tree.

## Containers are not virtual machines

| | Virtual machine | Container |
|---|---|---|
| Isolates | a full guest OS on virtualized hardware | a process and its filesystem/network on a shared host kernel |
| Start time | seconds to minutes | milliseconds to seconds |
| Overhead | a whole OS per VM | small; containers share the host kernel |
| Disk use | large disk image per VM | layers shared and cached between images |

A container is a normal Linux process with extra isolation provided by the kernel (namespaces for process/network/filesystem, and cgroups for resource limits). It does **not** contain its own kernel. This is why containers are fast and cheap, and why the host kernel's version still matters.

## Image, container, registry: three different things

| Thing | Meaning | Analogy |
|---|---|---|
| image | a read-only, built package of files, layers, and metadata | a template or a class definition |
| container | a running instance of an image with its own writable layer | an object instantiated from the class |
| registry | a place that stores and distributes images | a package index such as PyPI, but for images |

Docker Hub is the default public registry. `docker pull python:3.13-slim` downloads an image; `docker run` creates a container from it. Deleting a container does not delete the image, and deleting an image does not affect a running container that was already started from it.

## Layers and why they matter

An image is built from a sequence of instructions in a Dockerfile. Each instruction that changes the filesystem (`RUN`, `COPY`, `ADD`) produces a **layer**. Layers stack on top of each other, and Docker caches each one.

```dockerfile
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
```

Because `requirements.txt` rarely changes while code changes constantly, putting `COPY requirements.txt` before `COPY . .` means the dependency-install layer is reused on every rebuild. Reordering these two lines makes every build reinstall dependencies, which is slower but not incorrect. Layer ordering is a speed and caching decision, not magic.

## The basic workflow

```text
write Dockerfile  →  docker build  →  image  →  docker run  →  container
                          ↑                    ↓
                     push to registry     pull from registry (other machines)
```

You build an image once, store it in a registry, and run the same image on your laptop, a CI runner, and the production server. The same bytes produce the same behavior everywhere, which is the core Docker promise.

## What Docker gives Django

- Reproducible Python and system dependencies across machines.
- A clear place to state the exact runtime: base image, packages, environment.
- Easy multi-service topology (web, database, cache, worker, proxy) via Compose.
- A deployable artifact (the image) that is independent of a specific server's installed Python.

## What Docker does not give you

Docker does **not** automatically provide:

- secure secrets handling,
- TLS certificates and HTTPS,
- database backups and durability,
- monitoring, logging rotation, or alerting,
- a firewall policy,
- a safe deployment or rollback strategy.

Containers make these concerns more explicit and more portable, but they do not solve them. A Dockerized Django app with `DEBUG=True`, no backups, and an exposed PostgreSQL port is just as broken as a non-Docker one.

## When Docker is worth it

Use Docker when repeatability and multi-service clarity help your team, when you deploy to a platform that consumes images, or when you want the same environment in development, CI, and production.

Do not adopt Docker for a single-process hobby project purely for fashion. A well-managed systemd deployment can be simpler and safer for that case. See [Choose your stack](../getting-started/choose-a-stack.md) for the decision matrix.

## Next

The rest of this section builds up the full toolchain: [write a Dockerfile](dockerfile-from-zero.md), [build and run images](build-and-run.md), [compose multiple services](docker-compose-from-zero.md), and [operate Docker in production](production-docker.md).
