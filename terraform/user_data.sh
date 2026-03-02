#!/bin/bash
set -e

S3_BUCKET="${s3_bucket}"
S3_OBJECT="${s3_object}"
APP_DIR="/opt/chucknoris-jokes"

echo "========================================="
echo "  Chuck Norris Jokes - Setup Script"
echo "========================================="

echo "[$(date +%H:%M:%S)] Updating system..."
dnf update -y

echo "[$(date +%H:%M:%S)] Installing dependencies..."
dnf install -y dnf-utils curl git

echo "[$(date +%H:%M:%S)] Installing Docker..."
dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

echo "[$(date +%H:%M:%S)] Starting Docker service..."
systemctl start docker
systemctl enable docker

echo "[$(date +%H:%M:%S)] Installing Docker Compose (standalone)..."
curl -SL "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-linux-x86_64" \
    -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

echo "[$(date +%H:%M:%S)] Creating application directory..."
mkdir -p "$APP_DIR"

echo "[$(date +%H:%M:%S)] Downloading application files from S3..."
aws s3 cp "s3://${S3_BUCKET}/${S3_OBJECT}" "$APP_DIR/app-files.zip"

echo "[$(date +%H:%M:%S)] Extracting application files..."
cd "$APP_DIR"
unzip -o app-files.zip
rm app-files.zip

echo "[$(date +%H:%M:%S)] Building and starting containers..."
cd "$APP_DIR/docker"
docker-compose up -d --build

echo "[$(date +%H:%M:%S)] Waiting for application to be healthy..."
sleep 10

MAX_ATTEMPTS=30
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  if curl -f http://localhost/health > /dev/null 2>&1; then
    echo "[$(date +%H:%M:%S)] Application is healthy!"
    break
  fi
  ATTEMPT=$((ATTEMPT + 1))
  echo "[$(date +%H:%M:%S)] Waiting for application... (attempt $ATTEMPT/$MAX_ATTEMPTS)"
  sleep 5
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
  echo "[$(date +%H:%M:%S)] ERROR: Application failed to become healthy"
  docker-compose logs
  exit 1
fi

echo "========================================="
echo "  Deployment Complete!"
echo "========================================="
echo "Application URL: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "========================================="
