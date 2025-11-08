#!/bin/bash
set -e

DOCKER_USERNAME=$1
IMAGE_TAG=$2
DOCKER_PASSWORD=$3
DEPLOYMENT_ENV=$4

APP_DIR="/home/ubuntu/quotes-app"

echo "========================================"
echo "  Deploying Quotes Application"
echo "========================================"
echo "Directory: $APP_DIR"
echo "Docker Username: $DOCKER_USERNAME"
echo "Image Tag: $IMAGE_TAG"
echo "Deployment: $DEPLOYMENT_ENV"
echo "Timestamp: $(date)"
echo "========================================"

cd $APP_DIR

echo "Logging into Docker Hub..."
echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin

echo "Stopping existing containers..."
docker-compose down 2>/dev/null || true

echo "Cleaning up old resources..."
docker container prune -f || true
docker image prune -af --filter "until=24h" || true

echo "Creating environment configuration..."
cat > $APP_DIR/.env << EOF
DOCKER_USERNAME=${DOCKER_USERNAME}
IMAGE_TAG=${IMAGE_TAG}
DEPLOYMENT_ENV=${DEPLOYMENT_ENV}
EOF

cat > $APP_DIR/.deployment-info << EOF
DEPLOYMENT_ENV=${DEPLOYMENT_ENV}
IMAGE_TAG=${IMAGE_TAG}
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
HOSTNAME=$(hostname)
EOF

cat > $APP_DIR/nginx-deployment.conf << EOF
add_header X-Deployment-Environment "${DEPLOYMENT_ENV}" always;
add_header X-App-Version "${IMAGE_TAG}" always;
add_header X-Hostname "$(hostname)" always;
EOF

if [ ! -L /etc/nginx/sites-enabled/quotes-app ]; then
    echo "Setting up Nginx configuration..."
    sudo cp $APP_DIR/nginx-config/quotes-app.conf /etc/nginx/sites-available/quotes-app
    sudo ln -sf /etc/nginx/sites-available/quotes-app /etc/nginx/sites-enabled/quotes-app
    sudo rm -f /etc/nginx/sites-enabled/default
    sudo nginx -t
fi

echo "Pulling Docker images..."
docker-compose pull

echo "Starting Docker containers..."
docker-compose up -d

echo "Waiting for containers to be ready..."
sleep 30

echo "Reloading Nginx..."
sudo nginx -t && sudo systemctl reload nginx

echo "========================================"
echo "Container Status:"
docker-compose ps
echo ""
echo "Nginx Status:"
sudo systemctl status nginx --no-pager | head -5
echo "========================================"

RUNNING=$(docker-compose ps -q | wc -l)
EXPECTED=3

if [ $RUNNING -eq $EXPECTED ]; then
    echo ""
    echo "✅ DEPLOYMENT SUCCESSFUL!"
    echo "   Containers: $RUNNING/$EXPECTED running"
    echo "   Environment: $DEPLOYMENT_ENV"
    echo "   Version: $IMAGE_TAG"
    echo ""
    
    echo "Testing endpoints..."
    curl -s http://localhost/health && echo " ✅ Health check passed"
    
    echo ""
    echo "Deployment Info:"
    curl -s http://localhost/deployment-info 2>/dev/null || echo "Deployment info endpoint not ready"
    echo ""
    
    exit 0
else
    echo ""
    echo "❌ DEPLOYMENT FAILED!"
    echo "   Expected: $EXPECTED containers"
    echo "   Running: $RUNNING containers"
    echo ""
    docker-compose logs --tail=50
    exit 1
fi
