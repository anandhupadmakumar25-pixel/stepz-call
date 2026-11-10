#!/usr/bin/env bash
set -e

echo "=========================================="
echo "  Stepz Call - VPS Auto Deployment Setup"
echo "=========================================="

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$APP_DIR"

# 1. Install system prerequisites
echo "[1/6] Updating packages & installing system dependencies..."
sudo apt-get update -y
sudo apt-get install -y python3 python3-pip python3-venv nginx

# 2. Virtual environment setup
echo "[2/6] Setting up Python virtual environment..."
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi

source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# 3. Environment configuration
echo "[3/6] Setting up .env configuration..."
if [ ! -f ".env" ]; then
    cp .env.example .env
    echo ".env created from .env.example"
fi

# 4. Database migrations & Static collection
echo "[4/6] Running database migrations..."
python manage.py migrate --noinput

echo "[5/6] Collecting static assets..."
python manage.py collectstatic --noinput

# 5. Systemd service configuration
echo "[6/6] Configuring systemd service..."
# Replace path in service template if needed
sed "s|/var/www/stepz_call/backend|$APP_DIR|g" stepz-call.service | sudo tee /etc/systemd/system/stepz-call.service > /dev/null

sudo systemctl daemon-reload
sudo systemctl enable --now stepz-call
sudo systemctl restart stepz-call

echo "=========================================="
echo "  Stepz Call Backend Service is LIVE!"
echo "=========================================="
sudo systemctl status stepz-call --no-pager
