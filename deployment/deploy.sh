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

# Change to app directory
cd $APP_DIR

# Verify AWS CLI
echo "Verifying AWS CLI..."
which aws || { echo "❌ AWS CLI not found"; exit 1; }
aws --version

# Login to Docker Hub
echo "Logging into Docker Hub..."
echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin

# Stop existing containers
echo "Stopping existing containers..."
docker-compose down 2>/dev/null || true

# Clean up
echo "Cleaning up old resources..."
docker container prune -f || true
docker image prune -af --filter "until=24h" || true

# Create .env file
echo "Creating environment configuration..."
cat > $APP_DIR/.env << EOF
DOCKER_USERNAME=${DOCKER_USERNAME}
IMAGE_TAG=${IMAGE_TAG}
DEPLOYMENT_ENV=${DEPLOYMENT_ENV}
EOF

# Create deployment info
cat > $APP_DIR/.deployment-info << EOF
DEPLOYMENT_ENV=${DEPLOYMENT_ENV}
IMAGE_TAG=${IMAGE_TAG}
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
HOSTNAME=$(hostname)
EOF

# Create Nginx deployment headers
cat > $APP_DIR/nginx-deployment.conf << EOF
# Auto-generated deployment headers
add_header X-Deployment-Environment "${DEPLOYMENT_ENV}" always;
add_header X-App-Version "${IMAGE_TAG}" always;
add_header X-Hostname "$(hostname)" always;
EOF

# Setup Nginx if not already configured
if [ ! -L /etc/nginx/sites-enabled/quotes-app ]; then
    echo "Setting up Nginx configuration..."
    sudo cp $APP_DIR/nginx-config/quotes-app.conf /etc/nginx/sites-available/quotes-app
    sudo ln -sf /etc/nginx/sites-available/quotes-app /etc/nginx/sites-enabled/quotes-app
    sudo rm -f /etc/nginx/sites-enabled/default
    sudo nginx -t
fi

# Pull latest images
echo "Pulling Docker images..."
docker-compose pull

# Start containers
echo "Starting Docker containers..."
docker-compose up -d

# Wait for startup
echo "Waiting for containers to be ready..."
sleep 30

# Reload Nginx
echo "Reloading Nginx..."
sudo nginx -t && sudo systemctl reload nginx

# Check status
echo "========================================"
echo "Container Status:"
docker-compose ps
echo ""
echo "Nginx Status:"
sudo systemctl status nginx --no-pager | head -5
echo "========================================"

# Verify deployment
RUNNING=$(docker-compose ps -q | wc -l)
EXPECTED=3

if [ $RUNNING -eq $EXPECTED ]; then
    echo ""
    echo "✅ DEPLOYMENT SUCCESSFUL!"
    echo "   Containers: $RUNNING/$EXPECTED running"
    echo "   Environment: $DEPLOYMENT_ENV"
    echo "   Version: $IMAGE_TAG"
    echo ""
    
    # Test endpoints
    echo "Testing endpoints..."
    curl -s http://localhost/health && echo " ✅ Health check passed"
    
    echo ""
    echo "Deployment Info:"
    curl -s http://localhost/deployment-info | jq '.' 2>/dev/null || curl -s http://localhost/deployment-info
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
