# Summary

- [Welcome](README.md)
- [Import into GitBook](GITBOOK_SETUP.md)

## Start here

- [1. The production mental model](foundations/01-mental-model.md)
- [2. The request journey](foundations/02-request-journey.md)
- [3. Choose your stack](foundations/03-choose-your-stack.md)
- [4. Variables and naming convention](foundations/04-variables-and-layout.md)

## Build a production-aware Django project

- [5. Repository hygiene and dependencies](application/01-repository-and-dependencies.md)
- [6. Production settings and secrets](application/02-production-settings-and-secrets.md)
- [7. Static files, media, migrations, and health checks](application/03-static-media-migrations-health.md)
- [8. WSGI and ASGI explained](application/04-wsgi-and-asgi.md)
- [9. Email, background work, cache, and external services](application/05-email-background-work.md)

## Build the server foundation

- [9. VPS, Ubuntu, DNS, and provider controls](server/01-vps-dns-provider.md)
- [10. SSH, users, permissions, and directories](server/02-ssh-users-permissions.md)
- [11. PostgreSQL: private data layer](server/03-postgresql.md)
- [12. systemd and environment files](server/04-systemd-and-environment.md)

## Deployment stacks

- [13. Gunicorn: the WSGI application server](stacks/01-gunicorn.md)
- [14. Nginx + Gunicorn + PostgreSQL](stacks/02-nginx-gunicorn-postgres.md)
- [15. Apache + Gunicorn + PostgreSQL](stacks/03-apache-gunicorn-postgres.md)
- [16. Apache + mod_wsgi](stacks/04-apache-modwsgi.md)
- [17. Caddy + Gunicorn](stacks/05-caddy-gunicorn.md)
- [18. ASGI: Uvicorn, Daphne, Hypercorn, and WebSockets](stacks/06-asgi-websockets.md)
- [19. Docker Compose](stacks/07-docker-compose.md)
- [20. PaaS, managed hosting, serverless, and Kubernetes](stacks/08-managed-and-kubernetes.md)
- [21. uWSGI + Nginx](stacks/09-uwsgi-nginx.md)
- [22. Other valid options](stacks/10-other-valid-options.md)

## Security and day-2 operations

- [21. TLS, certificates, redirects, and HSTS](operations/01-tls-https.md)
- [22. Firewall, SSH, Fail2Ban, and host security](operations/02-firewall-ssh-and-host-security.md)
- [23. Safe deployments, migrations, and rollbacks](operations/03-deployment-runbooks.md)
- [24. Logging, monitoring, and incident response](operations/04-observability-and-incidents.md)
- [25. Backups, restore drills, and disaster recovery](operations/05-backups-and-disaster-recovery.md)
- [26. Testing, CI, staging, and smoke tests](operations/06-testing-ci-staging.md)
- [27. Scaling without premature complexity](operations/07-scaling.md)

## Publish and maintain as open source

- [28. Publishing an open-source project](open-source/01-publishing-a-project.md)
- [29. License, governance, contribution, and security policy](open-source/02-license-governance-security.md)
- [30. Releases, SemVer, changelogs, and support](open-source/03-releases-and-maintenance.md)

## Reference

- [Reference configurations](reference/01-reference-configurations.md)
- [Command checklists](reference/02-checklists.md)
- [Troubleshooting map](reference/03-troubleshooting.md)
- [Glossary](reference/04-glossary.md)
- [Official sources](reference/05-official-sources.md)
- [Complete all-in-one handbook](appendix/complete-handbook.md)
