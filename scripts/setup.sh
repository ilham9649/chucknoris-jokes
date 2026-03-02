#!/bin/bash
set -e

S3_BUCKET="${S3_BUCKET}"
S3_OBJECT="${S3_OBJECT}"
APP_DIR="/opt/chucknoris-jokes"

echo "========================================="
echo "  Chuck Norris Jokes - Setup Script"
echo "========================================="

echo "[$(date +%H:%M:%S)] Installing dependencies..."
sudo dnf install -y dnf-utils curl git

echo "[$(date +%H:%M:%S)] Installing Docker..."
sudo dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

echo "[$(date +%H:%M:%S)] Starting Docker service..."
sudo systemctl start docker
sudo systemctl enable docker

echo "[$(date +%H:%M:%S)] Installing Docker Compose (standalone)..."
curl -SL "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-linux-x86_64" \
    -o /tmp/docker-compose \
    --chmod +x /tmp/docker-compose
sudo mv /tmp/docker-compose /usr/local/bin/docker-compose

echo "[$(date +%H:%M:%S)] Creating application directory..."
sudo mkdir -p "$APP_DIR"
sudo chown "$USER" "$APP_DIR"

echo "[$(date +%H:%M:%S)] Downloading application files from S3..."
aws s3 cp "s3://$S3_BUCKET/$S3_OBJECT" "$APP_DIR/app-files.tar.gz" \
    --region "${REGION}"

echo "[$(date +%H:%M:%S)] Extracting application files..."
cd "$APP_DIR"
tar -xzf app-files.tar.gz
rm app-files.tar.gz

echo "[$(date +%H:%M:%S)] Building Docker images..."
cd "$APP_DIR/docker"
docker-compose build

echo "[$(date +%H:%M:%S)] Stopping old containers..."
docker-compose down || true

echo "[$(date +%H:%M:%S)] Starting containers..."
docker-compose up -d

echo "[$(date +%H:%M:%S)] Waiting for Flask app..."
sleep 10

MAX_ATTEMPTS=30
ATTEMPT=0
while [ "$ATTEMPT" -lt "$MAX_ATTEMPTS" ]; do
    if docker ps | grep -q "chucknoris-jokes-app"; then
        echo "[$(date +%H:%M:%S)] Flask app is running!"
        break
    fi
    ATTEMPT=$((ATTEMPT + 1))
    echo "[$(date +%H:%M:%S)] Waiting for Flask... (attempt $ATTEMPT/$MAX_ATTEMPTS)"
    sleep 5
done

if [ "$ATTEMPT" -eq "$MAX_ATTEMPTS" ]; then
    echo "[$(date +%H:%M:%S)] ERROR: Flask app not running"
    docker-compose logs
    exit 1
fi

echo "[$(date +%H:%M:%S)] Waiting for nginx..."
sleep 5

MAX_ATTEMPTS=30
ATTEMPT=0
while [ "$ATTEMPT" -lt "$MAX_ATTEMPTS" ]; do
    if curl -f http://localhost/health > /dev/null 2>&1; then
        echo "[$(date +%H:%M:%S)] nginx is healthy!"
        break
    fi
    ATTEMPT=$((ATTEMPT + 1))
    echo "[$(date +%H:%M:%S)] Waiting for nginx... (attempt $ATTEMPT/$MAX_ATTEMPTS)"
    sleep 3
done

if [ "$ATTEMPT" -eq "$MAX_ATTEMPTS" ]; then
    echo "[$(date +%H:%M:%S)] ERROR: nginx not healthy"
    docker-compose logs
    exit 1
fi

echo "========================================="
echo "  Chuck Norris Jokes - Deployment Complete!"
echo "========================================="
echo "  Application URL: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "========================================="
