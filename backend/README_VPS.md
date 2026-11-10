# Stepz Call - Backend VPS Hosting Guide

This archive contains the production-ready Django REST API backend for **Stepz Call CRM**, pre-configured for deployment on any Linux VPS (Ubuntu, Debian, CentOS, AlmaLinux, etc.).

---

## Method 1: Automatic 1-Script Setup (Recommended for Ubuntu/Debian)

1. **Upload and extract the zip on your VPS**:
   ```bash
   mkdir -p /var/www/stepz_call
   cd /var/www/stepz_call
   unzip stepz_call_backend.zip
   ```

2. **Make the deploy script executable and run it**:
   ```bash
   chmod +x deploy_vps.sh
   bash deploy_vps.sh
   ```
   *This script automatically updates apt packages, installs Python 3, venv, and Nginx, creates the virtualenv, installs all dependencies, runs database migrations, collects static assets, and registers `stepz-call.service` as an auto-restarting systemd background service!*

3. **Configure Nginx Reverse Proxy (Optional, for Domain/Port 80/443)**:
   ```bash
   sudo cp nginx.conf /etc/nginx/sites-available/stepz-call
   sudo ln -s /etc/nginx/sites-available/stepz-call /etc/nginx/sites-enabled/
   sudo nginx -t
   sudo systemctl restart nginx
   ```

4. **SSL / HTTPS with Certbot (Free Let's Encrypt)**:
   ```bash
   sudo apt install -y certbot python3-certbot-nginx
   sudo certbot --nginx -d your-domain.com
   ```

---

## Method 2: Docker Setup (1 Command)

If your VPS has Docker and Docker Compose installed:
```bash
docker compose up -d --build
```
Your API is now live on `http://YOUR_VPS_IP:8000/api/v1/`!

---

## Service Management Commands

- **Check status**: `sudo systemctl status stepz-call`
- **Restart service**: `sudo systemctl restart stepz-call`
- **View live logs**: `sudo journalctl -u stepz-call -f`
- **Stop service**: `sudo systemctl stop stepz-call`
