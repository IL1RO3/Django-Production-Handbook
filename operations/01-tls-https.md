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
