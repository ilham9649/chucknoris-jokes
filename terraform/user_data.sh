#!/bin/bash
set -e

S3_BUCKET="${S3_BUCKET}"
S3_OBJECT="${S3_OBJECT}"
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

echo "[$(date +%H:%M:%S)] Ensuring curl is available..."
if ! command -v curl &> /dev/null; then
  echo "ERROR: curl not found after installation"
  exit 1
fi

echo "[$(date +%H:%M:%S)] Starting Docker service..."
systemctl start docker
systemctl enable docker

echo "[$(date +%H:%M:%S)] Installing Docker Compose (standalone)..."
curl -SL "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-linux-x86_64" \
    -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

echo "[$(date +%H:%M:%S)] Creating application directory..."
mkdir -p "$APP_DIR"

echo "[$(date +%H:%M:%S)] Extracting application files..."
cd "$APP_DIR"
tar -xzf app-files.tar.gz
rm app-files.tar.gz

echo "[$(date +%H:%M:%S)] Building Docker images..."
cd "$APP_DIR/docker"
docker-compose build

echo "[$(date +%H:%M:%S)] Starting Docker containers..."
docker-compose up -d

echo "[$(date +%H:%M:%S)] Waiting for containers to start..."
sleep 10

echo "[$(date +%H:%M:%S)] Checking Flask app..."
MAX_ATTEMPTS=10
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if docker ps | grep -q "chucknoris-jokes-app"; then
        echo "[$(date +%H:%M:%S)] App container is running!"
        break
    fi
    ATTEMPT=$((ATTEMPT + 1))
    sleep 5
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    echo "[$(date +%H:%M:%S)] ERROR: Container not running"
    docker ps
    docker-compose logs
    exit 1
fi

echo "[$(date +%H:%M:%S)] Checking Flask health..."
MAX_ATTEMPTS=10
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if curl -f http://localhost:5000/health > /dev/null 2>&1; then
        echo "[$(date +%H:%M:%S)] Flask app is healthy!"
        break
    fi
    ATTEMPT=$((ATTEMPT + 1))
    sleep 5
done

if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
    echo "[$(date +%H:%M:%S)] ERROR: Flask app not healthy"
    docker-compose logs
    exit 1
fi

echo "[$(date +%H:%M:%S)] Checking nginx..."
MAX_ATTEMPTS=10
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if curl -f http://localhost/ > /dev/null 2>&1; then
        echo "[$(date +%H:%M:%S)] nginx is healthy!"
        break
    fi
    ATTEMPT=$((ATTEMPT + 1))
    sleep 5
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    echo "[$(date +%H:%M:%S)] ERROR: nginx not healthy"
    docker-compose logs
    exit 1
fi

echo "[$(date +%H:%M:%S)] Deployment Complete!"
echo "Application URL: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "========================================="
    ATTEMPT=$((ATTEMPT + 1))
    echo "[$(date +%H:%M:%S)] Waiting for Flask... (attempt $ATTEMPT/$MAX_ATTEMPTS)"
    sleep 3
done

if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
    echo "[$(date +%H:%M:%S)] ERROR: Flask app failed to become healthy"
    docker-compose logs
    exit 1
fi

echo "[$(date +%H:%M:%S)] Waiting for nginx to be healthy..."
sleep 5
MAX_ATTEMPTS=30
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if curl -f http://localhost/health > /dev/null 2>&1; then
        echo "[$(date +%H:%M:%S)] Application is healthy!"
        break
    fi
    ATTEMPT=$((ATTEMPT + 1))
    echo "[$(date +%H:%M:%S)] Waiting for nginx... (attempt $ATTEMPT/$MAX_ATTEMPTS)"
    sleep 5
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    echo "[$(date +%H:%M:%S)] ERROR: Application failed to become healthy"
    docker-compose logs
    exit 1
fi

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
