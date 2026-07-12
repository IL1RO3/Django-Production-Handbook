# 23. Other valid options and where they fit

The main stacks in this book cover the usual first choices. These tools are also valid in particular environments.

## Nginx Unit

Nginx Unit is an application server from the Nginx ecosystem that can run application processes with dynamic configuration. It can fit teams already using Unit, but it is a different product from Nginx itself. Learn its django-application/process model before choosing it as a “simpler Nginx.”

## Waitress

Waitress is a pure-Python WSGI server often valued for cross-platform simplicity. It can serve Django, but on Linux VPS deployments Gunicorn/uWSGI/mod_wsgi tend to have more common operational patterns. It is not normally the first choice for a high-concurrency Linux web stack.

## Traefik

Traefik is a reverse proxy/load balancer popular in Docker/Kubernetes environments because it discovers services dynamically through labels/providers.

**Use it when:** you have containerized multi-service routing and want dynamic configuration.

**Do not use it for:** one static Django service on a VPS when Nginx/Apache/Caddy would be simpler to understand.

## HAProxy

HAProxy is an excellent load balancer/proxy, especially in multi-instance/high-availability environments. It can sit in front of multiple Django application servers. For a single app on one host, it is usually unnecessary.

## CDN and object storage

A CDN can cache static content near users and absorb bandwidth. Object storage can hold media/uploads outside the app host.

**Benefits:** offloads static/media, improves global delivery, reduces single-disk risk.

**Responsibilities:** cache invalidation, signed/private media policy, origin access, upload configuration, storage backup/lifecycle, and correct proxy headers.

## Cloud load balancers

Cloud providers often offer managed HTTP/TLS load balancers. These can terminate TLS and distribute traffic to multiple app instances. Django must be configured carefully to understand forwarded HTTPS headers, and app instances must be stateless enough for multiple replicas.

## The selection rule

A technology is not better because it has more features. Prefer the smallest toolset that your team can correctly configure, monitor, patch, back up, and recover.

## Nginx Unit mental model

Nginx Unit is controlled through an API/config model rather than traditional Nginx `server` blocks. It can run application processes directly and update configuration dynamically. This can be attractive for platforms, but a beginner must learn Unit's listener, route, application, and process model. Do not confuse it with ordinary Nginx reverse proxy config.

## Waitress mental model

Waitress is a WSGI server written in Python. It is simple and cross-platform, which can be helpful on Windows or constrained environments. On a Linux VPS, the ecosystem around Gunicorn, uWSGI, and mod_wsgi is more common for Django production. If you choose Waitress, still put a reverse proxy in front for TLS/static files and keep it private.

## Traefik mental model

Traefik shines when services appear/disappear dynamically, especially in Docker and Kubernetes. Instead of manually writing every route, labels or providers tell Traefik how to route traffic.

That is useful when you have many containers. It is unnecessary overhead for a single Django service that can be described clearly in one Nginx, Apache, or Caddy config file.

## HAProxy mental model

HAProxy is excellent at load balancing and health checks:

```text
HAProxy
  -> Django app server A
  -> Django app server B
  -> Django app server C
```

It is usually placed in front of multiple app instances. For one app process on one server, it rarely adds value.

## CDN and object storage request path

Static/media architecture may evolve into:

```text
browser
  -> CDN
  -> object storage or origin server
```

For public static assets, this is straightforward. For user media, decide whether files are public, private, signed, expiring, cacheable, or subject to deletion rules. Private media needs more than "upload it to S3."

## Cloud load balancer request path

A managed load balancer often does this:

```text
browser HTTPS
  -> cloud load balancer terminates TLS
  -> private app instance HTTP
  -> Django
```

Django must understand the original scheme through trusted forwarded headers. App instances must be stateless enough that any instance can handle the next request.

## Final stack decision checklist

Before choosing any stack, answer:

```text
[ ] Who terminates HTTPS?
[ ] Who serves static files?
[ ] Who runs Python workers?
[ ] How does Django receive secrets?
[ ] Where does PostgreSQL run?
[ ] Where do media files live?
[ ] What restarts after reboot?
[ ] Where are logs?
[ ] How are backups created and restored?
[ ] How is a bad deploy rolled back?
```

If you cannot answer those questions, the stack is not ready for production yet.
