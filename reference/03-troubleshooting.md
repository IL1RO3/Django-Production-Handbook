# Troubleshooting map

## Domain / connection

```bash
dig +short <DOMAIN>
curl -I http://<DOMAIN>
curl -Iv https://<DOMAIN>
sudo ufw status numbered
```

## Nginx

```bash
sudo nginx -t
sudo systemctl status nginx
sudo tail -n 100 /var/log/nginx/error.log
```

## Apache

```bash
sudo apache2ctl configtest
sudo systemctl status apache2
sudo tail -n 100 /var/log/apache2/error.log
```

## Application service

```bash
sudo systemctl status <APP_NAME>
sudo journalctl -u <APP_NAME> -n 100 --no-pager
sudo journalctl -u <APP_NAME> -f
curl -I http://127.0.0.1:8000/
```

## Django configuration

```bash
sudo -u <APP_USER> -H bash -lc '
cd /srv/<APP_NAME>/app
/srv/<APP_NAME>/venv/bin/python manage.py check --deploy
'
```

## PostgreSQL

```bash
sudo systemctl status postgresql
sudo -u postgres psql -d <DB_NAME> -c "SELECT 1;"
```

## Certificate renewal

```bash
sudo certbot certificates
sudo certbot renew --dry-run
```

## Git deployment state

```bash
sudo -u <DEPLOY_USER> -H bash -lc '
cd /srv/<APP_NAME>/app
git status --short --branch
git log -1 --oneline
git remote -v
'
```

## Interpret before changing

| Result | Meaning | Next step |
|---|---|---|
| Proxy config invalid | web server cannot safely reload | fix config syntax/path before restart |
| App service inactive | upstream unavailable | read app journal, do not only restart repeatedly |
| localhost app works but public domain fails | proxy/DNS/firewall/TLS issue | inspect web-server access/error logs |
| app returns 500 | Django/config/database issue | read traceback from app journal |
| app returns 404 for one record | URL/data/filter mismatch | inspect generated URL, stored fields, query filters |
| static 404 | collection/alias/permissions mismatch | run collectstatic, verify directory and alias |
