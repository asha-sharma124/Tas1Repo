# # #!/bin/bash
# # set -e

# # DOCKER_USERNAME=$1
# # IMAGE_TAG=$2
# # DOCKER_PASSWORD=$3
# # DEPLOYMENT_ENV=$4

# # APP_DIR="/home/ubuntu/quotes-app"

# # echo "========================================"
# # echo "  Deploying Quotes Application"
# # echo "========================================"
# # echo "Directory: $APP_DIR"
# # echo "Docker Username: $DOCKER_USERNAME"
# # echo "Image Tag: $IMAGE_TAG"
# # echo "Deployment: $DEPLOYMENT_ENV"
# # echo "Timestamp: $(date)"
# # echo "========================================"

# # cd $APP_DIR

# # echo "Logging into Docker Hub..."
# # echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin

# # echo "Stopping existing containers..."
# # docker-compose down 2>/dev/null || true

# # echo "Cleaning up old resources..."
# # docker container prune -f || true
# # docker image prune -af --filter "until=24h" || true

# # echo "Creating environment configuration..."
# # cat > $APP_DIR/.env << EOF
# # DOCKER_USERNAME=${DOCKER_USERNAME}
# # IMAGE_TAG=${IMAGE_TAG}
# # DEPLOYMENT_ENV=${DEPLOYMENT_ENV}
# # EOF

# # cat > $APP_DIR/.deployment-info << EOF
# # DEPLOYMENT_ENV=${DEPLOYMENT_ENV}
# # IMAGE_TAG=${IMAGE_TAG}
# # TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
# # HOSTNAME=$(hostname)
# # EOF

# # cat > $APP_DIR/nginx-deployment.conf << EOF
# # add_header X-Deployment-Environment "${DEPLOYMENT_ENV}" always;
# # add_header X-App-Version "${IMAGE_TAG}" always;
# # add_header X-Hostname "$(hostname)" always;
# # EOF

# # if [ ! -L /etc/nginx/sites-enabled/quotes-app ]; then
# #     echo "Setting up Nginx configuration..."
# #     sudo cp $APP_DIR/nginx-config/quotes-app.conf /etc/nginx/sites-available/quotes-app
# #     sudo ln -sf /etc/nginx/sites-available/quotes-app /etc/nginx/sites-enabled/quotes-app
# #     sudo rm -f /etc/nginx/sites-enabled/default
# #     sudo nginx -t
# # fi

# # echo "Pulling Docker images (this may take 5-10 minutes)..."
# # echo "Started at: $(date)"

# # # Pull with minimal output
# # docker-compose pull 2>&1 | grep -E "Pulling|Downloaded|Status:" || true

# # echo "Images pulled at: $(date)"

# # echo "Starting Docker containers..."
# # docker-compose up -d

# # echo "Waiting for containers to be ready..."
# # sleep 30

# # echo "Reloading Nginx..."
# # sudo nginx -t && sudo systemctl reload nginx

# # echo "========================================"
# # echo "Container Status:"
# # docker-compose ps
# # echo ""
# # echo "Nginx Status:"
# # sudo systemctl status nginx --no-pager | head -5
# # echo "========================================"

# # RUNNING=$(docker-compose ps -q | wc -l)
# # EXPECTED=3

# # if [ $RUNNING -eq $EXPECTED ]; then
# #     echo ""
# #     echo "✅ DEPLOYMENT SUCCESSFUL!"
# #     echo "   Containers: $RUNNING/$EXPECTED running"
# #     echo "   Environment: $DEPLOYMENT_ENV"
# #     echo "   Version: $IMAGE_TAG"
# #     echo ""
    
# #     echo "Testing endpoints..."
# #     curl -s http://localhost/health && echo " ✅ Health check passed"
    
# #     echo ""
# #     echo "Deployment completed at: $(date)"
# #     echo ""
    
# #     exit 0
# # else
# #     echo ""
# #     echo "❌ DEPLOYMENT FAILED!"
# #     echo "   Expected: $EXPECTED containers"
# #     echo "   Running: $RUNNING containers"
# #     echo ""
# #     docker-compose logs --tail=50
# #     exit 1
# # fi


#!/bin/bash
set -e

DOCKER_USERNAME=$1
IMAGE_TAG=$2
DOCKER_PASSWORD=$3
DEPLOYMENT_ENV=$4

APP_DIR="/home/ubuntu/quotes-app"

echo "Deploying $IMAGE_TAG ($DEPLOYMENT_ENV) at $(date)"

cd "$APP_DIR"

echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin

echo "Stopping containers gracefully..."
docker-compose down --timeout 30 || true

echo "Cleaning up resources..."
docker container prune -f || true
docker image prune -af --filter "until=24h" || true

cat > "$APP_DIR/.env" <<EOF
DOCKER_USERNAME=${DOCKER_USERNAME}
IMAGE_TAG=${IMAGE_TAG}
DEPLOYMENT_ENV=${DEPLOYMENT_ENV}
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
EOF

echo "Pulling images..."
docker-compose pull -q

echo "Starting containers..."
docker-compose up -d

echo "Waiting for services to be ready..."
sleep 20

# Wait for API health check (port 5001 expected response 200 on /health)
for i in {1..30}; do
    if curl -sf http://localhost:5001/health > /dev/null 2>&1; then
        echo "API ready"
        break
    fi
    echo "Waiting for API ($i/30)..."
    sleep 2
done

# Wait for frontend health check (port 5002 expected response 200 on /)
for i in {1..30}; do
    if curl -sf http://localhost:5002/ > /dev/null 2>&1; then
        echo "Frontend ready"
        break
    fi
    echo "Waiting for frontend ($i/30)..."
    sleep 2
done

# Update nginx cache busting headers
cat > "$APP_DIR/nginx-deployment.conf" <<EOF
add_header X-Deployment-Environment "${DEPLOYMENT_ENV}" always;
add_header X-App-Version "${IMAGE_TAG}" always;
add_header X-Hostname "$(hostname)" always;
add_header Cache-Control "no-cache, no-store, must-revalidate" always;
add_header Pragma "no-cache" always;
add_header Expires "0" always;
EOF

# Ensure symlink to nginx config is correct
if [ ! -L /etc/nginx/sites-enabled/quotes-app ]; then
    sudo cp "$APP_DIR/nginx-config/quotes-app.conf" /etc/nginx/sites-available/quotes-app
    sudo ln -sf /etc/nginx/sites-available/quotes-app /etc/nginx/sites-enabled/quotes-app
    sudo rm -f /etc/nginx/sites-enabled/default
fi

echo "Reloading nginx..."
sudo nginx -t
sudo systemctl reload nginx

# ec
# #!/bin/bash
# set -e

# DOCKER_USERNAME=$1
# IMAGE_TAG=$2
# DOCKER_PASSWORD=$3
# DEPLOYMENT_ENV=$4

# APP_DIR="/home/ubuntu/quotes-app"

# echo "Deploying $IMAGE_TAG ($DEPLOYMENT_ENV) at $(date)"

# cd $APP_DIR

# echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin

# echo "Stopping containers gracefully..."
# docker-compose down --timeout 30 2>/dev/null || true

# echo "Cleaning up resources..."
# docker container prune -f || true
# docker image prune -af --filter "until=24h" || true

# cat > $APP_DIR/.env << EOF
# DOCKER_USERNAME=${DOCKER_USERNAME}
# IMAGE_TAG=${IMAGE_TAG}
# DEPLOYMENT_ENV=${DEPLOYMENT_ENV}
# TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
# EOF

# echo "Pulling images..."
# docker-compose pull -q

# echo "Starting containers..."
# docker-compose up -d

# echo "Waiting for services to be ready..."
# sleep 20

# # API health check wait
# for i in {1..30}; do
#     if curl -sf http://localhost:5001/health > /dev/null 2>&1; then
#         echo "API ready"
#         break
#     fi
#     echo "Waiting for API ($i/30)..."
#     sleep 2
# done

# # Frontend health check wait
# for i in {1..30}; do
#     if curl -sf http://localhost:5002/ > /dev/null 2>&1; then
#         echo "Frontend ready"
#         break
#     fi
#     echo "Waiting for frontend ($i/30)..."
#     sleep 2
# done

# # Update nginx with cache busting headers
# cat > $APP_DIR/nginx-deployment.conf << EOF
# add_header X-Deployment-Environment "${DEPLOYMENT_ENV}" always;
# add_header X-App-Version "${IMAGE_TAG}" always;
# add_header X-Hostname "$(hostname)" always;
# add_header Cache-Control "no-cache, no-store, must-revalidate" always;
# add_header Pragma "no-cache" always;
# add_header Expires "0" always;
# EOF

# if [ ! -L /etc/nginx/sites-enabled/quotes-app ]; then
#     sudo cp $APP_DIR/nginx-config/quotes-app.conf /etc/nginx/sites-available/quotes-app
#     sudo ln -sf /etc/nginx/sites-available/quotes-app /etc/nginx/sites-enabled/quotes-app
#     sudo rm -f /etc/nginx/sites-enabled/default
# fi

# echo "Reloading nginx..."
# sudo nginx -t && sudo systemctl reload nginx
