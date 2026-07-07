# 23. Other valid options and where they fit

The main stacks in this book cover the usual first choices. These tools are also valid in particular environments.

## Nginx Unit

Nginx Unit is an application server from the Nginx ecosystem that can run application processes with dynamic configuration. It can fit teams already using Unit, but it is a different product from Nginx itself. Learn its application/process model before choosing it as a “simpler Nginx.”

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
