# 24. TLS, HTTPS, redirects, and HSTS

HTTPS is HTTP protected by TLS. TLS provides confidentiality, integrity, and server identity verification for browser-to-server traffic.

## Certificate prerequisites

Before Let’s Encrypt/Certbot can issue a normal public certificate:

- `<DOMAIN>` must resolve to the intended server,
- inbound port 80 must be reachable for common HTTP validation methods,
- the reverse proxy must have a matching virtual host/server block,
- no unrelated proxy/CDN behavior should block validation unless deliberately configured.

## Certbot patterns

For Nginx:

```bash
sudo certbot --nginx -d <DOMAIN> -d <WWW_DOMAIN>
```

For Apache:

```bash
sudo certbot --apache -d <DOMAIN> -d <WWW_DOMAIN>
```

The plugins can obtain certificates and modify configuration to enable TLS/redirects. Read the resulting config. Automation is not a substitute for understanding which vhost is serving which hostname.

## Verify renewal

```bash
sudo certbot renew --dry-run
systemctl list-timers | grep certbot
```

## HTTP-to-HTTPS redirect

Keep port 80 open even after HTTPS works so HTTP visitors can be redirected and ACME renewal can use HTTP validation. Your public application should use HTTPS.

## HSTS

HSTS tells browsers to remember that a domain should use HTTPS. It is powerful because client browsers enforce it after receiving the header.

A safe progression:

1. Verify HTTPS and redirect correctness.
2. Start with a short `SECURE_HSTS_SECONDS` value.
3. Verify all intended subdomains support HTTPS before enabling `includeSubDomains`.
4. Do not use preload options casually; recovery from a mistake can be slow.

## Proxy-aware Django security

When TLS terminates at the proxy, configure the proxy to set `X-Forwarded-Proto` and Django to trust it only when the app server is private. Then secure cookies and `SECURE_SSL_REDIRECT` behave consistently.

## What Certbot is doing

When you run:

```bash
sudo certbot --nginx -d <DOMAIN> -d <WWW_DOMAIN>
```

Certbot typically does four jobs:

1. asks Let's Encrypt for a certificate for the listed names;
2. proves control of those names, often through an HTTP challenge on port 80;
3. stores certificate files on the server;
4. updates the Nginx config if you use the Nginx plugin.

The `-d` flags list every hostname that should appear on the certificate. A certificate for `example.com` does not automatically cover `www.example.com` unless both names are included or a wildcard certificate is used.

## What can go wrong during certificate issuance

| Symptom | Likely cause |
|---|---|
| DNS validation fails | domain does not point to this server yet |
| connection timeout | provider firewall or UFW blocks port 80 |
| wrong site answers | Nginx/Apache server block does not match `server_name`/vhost |
| too many redirects | HTTP challenge is being redirected through a broken HTTPS path |
| CDN interference | proxy/CDN is not forwarding the challenge as expected |

Fix the path from the public internet to port 80 before rerunning repeatedly. Certificate authorities enforce rate limits.

## Why port 80 usually stays open

After HTTPS works, port 80 should not serve the application insecurely. It should redirect to HTTPS. Keeping it open is still useful because:

- users who type `example.com` often start on HTTP;
- ACME HTTP validation may need port 80;
- redirects give a clean path to HTTPS.

The important rule is not "close port 80." The important rule is "do not serve sensitive application traffic over plain HTTP."
