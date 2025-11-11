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
# #docker rm -f quotes-app-app-1

# cat > $APP_DIR/.env << EOF
# DOCKER_USERNAME=${DOCKER_USERNAME}
# IMAGE_TAG=${IMAGE_TAG}
# DEPLOYMENT_ENV=${DEPLOYMENT_ENV}
# TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
# EOF

docker-compose pull -q

echo "Starting containers..."
docker-compose up -d

sleep 20


cd /etc/nginx/sites-enabled
rm -rf default
cp /home/ubuntu/quotes-app/quotes.conf /etc/nginx/conf.d/
sudo systemctl restart nginx