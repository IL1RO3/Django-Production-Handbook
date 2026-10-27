# Glossary

| Term | Meaning |
|---|---|
| ACME | protocol used by certificate authorities/clients such as Let's Encrypt/Certbot |
| ALLOWED_HOSTS | Django protection against unexpected Host headers |
| ASGI | asynchronous Python web-server gateway interface |
| bind mount | host file or directory mounted into a container at a specific path |
| build context | set of files Docker sends to the daemon when building an image |
| CDN | geographically distributed proxy/cache layer for public assets or traffic |
| CNAME | DNS record that aliases one hostname to another hostname |
| connection pool | shared set of database connections reused by application processes |
| container | running instance of an image with its own isolated filesystem and network |
| CSRF | protection against malicious cross-site form submissions |
| daemon | long-running background process/service |
| Docker Compose | tool that describes and runs a multi-service container application from YAML |
| Dockerfile | text file of instructions Docker uses to build an image |
| DNS | system mapping names to IP addresses |
| Gunicorn | Python WSGI application server |
| healthcheck | command that reports whether a service/container is ready or healthy |
| HSTS | browser policy remembering to use HTTPS |
| HTTP | web request/response protocol |
| HTTPS | HTTP over TLS encryption |
| idempotent task | task that can be retried without causing duplicate harmful effects |
| image | read-only, built package of layers from which containers are created |
| layer | single filesystem change in an image produced by a Dockerfile instruction |
| load balancer | component that distributes traffic across healthy app instances |
| localhost | network name for the same machine, commonly `127.0.0.1` or `::1` |
| migration | versioned Django database schema/data operation |
| mod_wsgi | Apache module hosting Python WSGI apps |
| named volume | Docker-managed persistent storage referenced by a name |
| NAT | network address translation between private and public networks |
| object storage | S3-compatible or cloud storage for files/media outside the app server disk |
| PgBouncer | lightweight PostgreSQL connection pooler |
| private IP | address reachable only inside a private network |
| public IP | address routable from the public internet |
| registry | service that stores and distributes container images |
| reverse proxy | public server forwarding requests to private upstream app service |
| socket | endpoint for process communication; can be TCP or Unix file socket |
| systemd | Linux service manager |
| TCP | transport protocol used by HTTP(S), SSH, PostgreSQL, Redis, and many APIs |
| TLS | cryptographic protocol behind HTTPS |
| TTL | DNS cache lifetime value used by resolvers |
| UFW | Ubuntu firewall management frontend |
| Unix socket | same-machine process communication endpoint represented as a file |
| volume | persistent storage managed outside the container's writable layer |
| VPS | virtual private server rented from a hosting provider |
| WSGI | traditional synchronous Python web-server gateway interface |
| zero-downtime deployment | deployment approach that keeps serving successful requests during release |
