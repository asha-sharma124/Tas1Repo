#!/bin/bash
set -e

DOCKER_USERNAME=$1
IMAGE_TAG=$2
DOCKER_PASSWORD=$3
DEPLOYMENT_ENV=$4

APP_DIR="/home/ubuntu/quotes-app"

cd $APP_DIR

echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin


docker-compose down 

docker container prune -f || true

docker image prune -af --filter "until=24h" || true
#docker rm -f quotes-app-app-1

if sudo lsof -i :80 >/dev/null; then
  echo "Port 80 is in use. Stopping nginx to free port..."
  sudo systemctl stop nginx || true
fi

cat > $APP_DIR/.env << EOF
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
