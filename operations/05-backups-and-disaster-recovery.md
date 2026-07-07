# 28. Backups, restore drills, and disaster recovery

A backup is only useful if it can be restored. A backup stored only on the same VPS is not sufficient for full server loss.

## What to back up

- PostgreSQL database dumps;
- user media/uploads if stored locally;
- protected environment files/secrets through a secure, documented recovery method;
- deployment config templates and service definitions (ideally Git, minus secrets);
- certificate material only if you have a reason; certificates can often be reissued, but account/config recovery matters.

## PostgreSQL custom-format dump

```bash
sudo -u postgres pg_dump \
  --format=custom \
  --no-owner \
  --no-privileges \
  --file=/var/backups/<APP_NAME>/postgresql/<APP_NAME>-$(date -u +%Y%m%dT%H%M%SZ).dump \
  <DB_NAME>
```

Verify the dump is readable:

```bash
sudo -u postgres pg_restore --list /var/backups/<APP_NAME>/postgresql/<FILE>.dump > /dev/null
```

## Restore drill into a separate database

Never first test a restore by overwriting production:

```bash
sudo -u postgres createdb <DB_NAME>_restore_test
sudo -u postgres pg_restore \
  --dbname=<DB_NAME>_restore_test \
  --no-owner \
  --no-privileges \
  /var/backups/<APP_NAME>/postgresql/<FILE>.dump
```

Inspect it, then remove the test database when done.

## Nightly systemd backup service

```ini
# /etc/systemd/system/<APP_NAME>-db-backup.service
[Unit]
Description=<APP_NAME> PostgreSQL backup
After=postgresql.service

[Service]
Type=oneshot
User=postgres
Group=postgres
UMask=0077
ExecStart=/usr/local/sbin/<APP_NAME>-db-backup
```

```ini
# /etc/systemd/system/<APP_NAME>-db-backup.timer
[Unit]
Description=Nightly <APP_NAME> PostgreSQL backup

[Timer]
OnCalendar=*-*-* 03:15:00 UTC
Persistent=true
Unit=<APP_NAME>-db-backup.service

[Install]
WantedBy=timers.target
```

`Persistent=true` means a missed run can be triggered after the machine comes back up.

## Off-server copy

Send encrypted backups to a different failure domain: object storage, another server, encrypted local storage, or a managed backup destination. Test the path and record retention policy.

## Disaster recovery questions

You should be able to answer:

- Where is the latest verified DB backup?
- Where are media files backed up?
- How do we restore a new server from Git + config + DB + media?
- Who can access the secrets needed to start the service?
- What is the acceptable data-loss window (RPO)?
- How quickly must service return (RTO)?

If there is no answer, the system has a recovery risk—not merely a documentation gap.
