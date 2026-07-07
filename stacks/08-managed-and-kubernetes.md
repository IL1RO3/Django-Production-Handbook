# 21. PaaS, managed hosting, serverless, and Kubernetes

## Managed PaaS

A PaaS generally accepts code or a container image and provides routing, TLS, logs, environment variables, process execution, and sometimes a managed database.

**Good fit:** solo developers/small teams that want fast deployment and less OS administration.

**Still your responsibility:** Django settings, migrations, data model, secrets, access control, application logs, backup policy, testing, vendor limits, and release/rollback workflow.

## Managed databases

A managed PostgreSQL service shifts patching, replication, and some backup burden to the provider. It does not mean “never export data” or “ignore restore testing.” You still need access controls, connection security, retention awareness, and recovery documentation.

## Serverless

Serverless functions can work for request-driven workloads, but a traditional stateful Django app may need adaptation for cold starts, storage, WebSockets, migrations, scheduled work, and database connections. Choose it for its operational/economic fit, not as a default replacement for a VPS.

## Kubernetes

Kubernetes coordinates containers across machines. Its core concepts include:

| Object | Role |
|---|---|
| Deployment | desired replica count and rollout behavior |
| Pod | running unit containing one/more containers |
| Service | stable internal network endpoint |
| Ingress/Gateway | HTTP/TLS entry routing |
| ConfigMap | non-secret config |
| Secret | sensitive configuration reference |
| PersistentVolume | durable storage abstraction |

**Use Kubernetes when:** you have multiple services, multiple environments, a team able to operate it, clear scaling/availability needs, and a reason to standardize orchestration.

**Do not start there when:** one Django app on one VPS is your reality. Kubernetes can make a simple system difficult to understand, debug, and secure.

## A sensible growth path

```text
single VPS + systemd
→ add backups/monitoring/staging
→ managed database or object storage
→ multiple app instances behind a proxy/load balancer
→ containers/Compose where helpful
→ managed container platform or Kubernetes only when justified
```

The best architecture is the smallest one that reliably meets present requirements and can be evolved without losing data or operational clarity.
