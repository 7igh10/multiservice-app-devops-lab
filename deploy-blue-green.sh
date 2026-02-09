#!/bin/bash
set -e

BLUE_VERSION=$APP_VERSION
GREEN_VERSION=$NEW_VERSION

echo "Current (blue): $BLUE_VERSION"
echo "New (green): $GREEN_VERSION"

echo "Starting green version..."
docker compose up -d backend_green --build

echo "Waiting for green to become healthy..."

for i in {1..10}; do
  STATUS=$(docker inspect --format='{{.State.Health.Status}}' multiservice-app-backend_green-1)
  echo "Health check attempt $i: $STATUS"

  if [ "$STATUS" = "healthy" ]; then
    echo "Green is healthy!"
    break
  fi

  sleep 5
done

if [ "$STATUS" != "healthy" ]; then
  echo "Green failed health check. Rolling back (keeping blue)."
  docker compose stop backend_green
  docker compose rm -f backend_green
  exit 1
fi

echo "Switching nginx to green..."

sed -i 's/backend_blue/backend_green/g' nginx/default.conf

docker compose restart nginx

echo "Stopping blue..."
docker compose stop backend_blue

echo "Deployment successful!"
