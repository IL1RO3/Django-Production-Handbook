# 10. VPS, Ubuntu, DNS, and provider controls

## VPS responsibilities

A VPS is a virtual machine rented from a provider. It gives you a public IP, CPU, memory, disk, and an operating system. In return, you own the operating responsibility: patches, network policy, secrets, backups, logs, and recovery.

A managed platform reduces some of this responsibility. It does not eliminate application configuration, migrations, data backups, or access control.

## Before deployment: where the app actually runs

A beginner-friendly production path usually looks like this:

```text
Your laptop
  -> Git repository
  -> VPS or platform
  -> public internet
```

The laptop is where you write code and run tests. Git is the transport and history system. The VPS is the always-on computer that runs the application, database, web server, background workers, and scheduled jobs. The internet reaches the VPS through a public IP address and DNS name.

Common hosting choices:

| Option | Best fit | Responsibility level |
|---|---|---|
| VPS | learning, small products, full control | high: OS, firewall, backups, services |
| Dedicated server | predictable heavy workloads | very high: hardware/provider coordination too |
| PaaS | teams that want less server administration | medium: app config, data, vendor limits |
| Managed database + app VPS | growing apps with valuable data | medium-high: app server plus database contract |
| Kubernetes | many services, platform team, container orchestration | very high unless managed and justified |

Choose the smallest boring server that can run the app comfortably, then document how to resize or migrate. For a modest Django app, 1-2 vCPU, 1-2 GB RAM, and SSD storage is often enough to start if PostgreSQL and background workers are not heavy. Watch memory and disk before upgrading CPU.

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

## IP addresses and DNS records

A public IP address identifies the server on the internet. A private IP address is reachable only inside a private network. A domain is just a human name until DNS records point it somewhere.

Useful records:

| Record | Purpose | Example use |
|---|---|---|
| A | hostname to IPv4 address | `example.com -> 203.0.113.10` |
| AAAA | hostname to IPv6 address | `example.com -> 2001:db8::10` |
| CNAME | hostname alias to another hostname | `www -> example.com` |
| MX | mail routing | receiving email for the domain |
| TXT | verification and email policy | SPF, DKIM, DMARC, provider checks |

Set DNS TTLs deliberately. A short TTL can help during migration, but it does not make every resolver update instantly. Plan DNS changes before certificate issuance, launch windows, and provider migrations.

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

## The network path in production

For a classic single-server deployment, the request path is:

```text
Browser
  -> DNS lookup
  -> public IP address
  -> provider firewall
  -> UFW on the VPS
  -> TCP port 443
  -> Nginx/Apache/Caddy
  -> Unix socket or localhost TCP port
  -> Gunicorn/Uvicorn
  -> Django
  -> PostgreSQL on localhost/private network
```

Key terms:

| Term | Meaning in deployment |
|---|---|
| TCP | transport protocol used by HTTP(S), SSH, PostgreSQL, Redis, and many APIs |
| port | numbered entry point on an IP address, such as 22, 80, 443, 5432 |
| socket | endpoint for process communication; can be TCP or Unix file socket |
| localhost | the same machine, usually `127.0.0.1` or `::1` |
| public IP | routable from the internet |
| private IP | reachable only inside a private network/VPC/LAN |
| NAT | address translation between private networks and public routes |
| proxy | server that receives a request and forwards it to another service |
| CDN | edge network that can cache, proxy, and protect public traffic |

When debugging, move along this path one layer at a time. Do not start by changing Django settings if DNS does not resolve, port 443 is blocked, or the proxy cannot reach the app server.

## Start with an LTS release

Use a supported Ubuntu LTS release and apply security updates. Record the OS release and provider details in private operations documentation so a future migration is reproducible.

## Provider controls to record

Keep a private operations note for each production server:

- provider and region;
- server size and disk size;
- public IPv4/IPv6 addresses;
- private network/VPC name if used;
- firewall/security group rules;
- DNS provider and authoritative nameservers;
- backup/snapshot settings;
- emergency access method.

This documentation matters during incidents. If the original deployer is unavailable, another maintainer should know where the server lives and which control panels can affect it.
