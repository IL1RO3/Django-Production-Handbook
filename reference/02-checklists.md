# Command checklists

## First public launch

```text
[ ] DNS resolves to the right server.
[ ] provider firewall allows only required ports.
[ ] UFW allows SSH/80/443 and denies other inbound traffic.
[ ] SSH key login works; root/password policy verified safely.
[ ] app runs as non-root service account.
[ ] PostgreSQL is private.
[ ] secrets are outside Git and permission-restricted.
[ ] DEBUG=False and ALLOWED_HOSTS are correct.
[ ] static files collected and served.
[ ] migrations applied.
[ ] HTTPS certificate works; renewal dry-run passes.
[ ] HTTP redirects to HTTPS.
[ ] service starts after reboot.
[ ] health endpoint and critical flow work.
[ ] backup exists, is verified, and copied off-host.
[ ] monitoring/error reporting is configured.
```

## Normal release

```text
[ ] local tests and Django checks pass.
[ ] migration reviewed.
[ ] Git working tree clean; commit/push complete.
[ ] server Git state inspected before pull.
[ ] code pulled with ff-only workflow.
[ ] migrate only if required.
[ ] collectstatic only if required.
[ ] app service restarted.
[ ] web-server config test/reload only if config changed.
[ ] health check and changed critical workflow tested.
[ ] logs monitored for new errors.
```

## Migration to another server

```text
[ ] target OS prepared; users/firewall/packages installed.
[ ] code cloned at intended release tag.
[ ] protected env file transferred securely.
[ ] database created and restore tested.
[ ] media copied/restored.
[ ] app service and proxy configured.
[ ] TLS certificate issued after DNS cutover or planned separately.
[ ] health/critical flow tested before switch.
[ ] DNS cutover completed and old server retained briefly for rollback.
[ ] backups/monitoring recreated on target.
```
