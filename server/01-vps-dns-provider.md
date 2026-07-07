# 9. VPS, Ubuntu, DNS, and provider controls

## VPS responsibilities

A VPS is a virtual machine rented from a provider. It gives you a public IP, CPU, memory, disk, and an operating system. In return, you own the operating responsibility: patches, network policy, secrets, backups, logs, and recovery.

A managed platform reduces some of this responsibility. It does not eliminate application configuration, migrations, data backups, or access control.

## DNS before certificates

For a normal public TLS certificate, the domain must resolve to the server that will answer the validation challenge.

Create DNS records first:

```text
A     <DOMAIN>       → <SERVER_IPV4>
A     <WWW_DOMAIN>   → <SERVER_IPV4>  # optional
```

Verify from a resolver:

```bash
dig +short <DOMAIN>
dig +short <WWW_DOMAIN>
```

DNS is only a name-to-address system. It does not proxy traffic unless you deliberately enable a CDN/proxy service. A CDN can add caching, DDoS controls, and TLS termination, but it introduces another layer whose origin connection must be configured and tested.

## Provider firewall versus UFW

Use two boundaries:

1. **Provider firewall/security group** — filters before traffic reaches the VPS.
2. **UFW host firewall** — filters on the Linux host.

For a simple web app, allow only:

```text
TCP 22    SSH administration
TCP 80    HTTP redirect and ACME validation
TCP 443   HTTPS application traffic
```

Do not open:

```text
5432  PostgreSQL
8000  Django development server
8001  Gunicorn/Uvicorn app server
6379  Redis
```

unless you have an explicit private-network architecture and source-IP restrictions.

## Start with an LTS release

Use a supported Ubuntu LTS release and apply security updates. Record the OS release and provider details in private operations documentation so a future migration is reproducible.
