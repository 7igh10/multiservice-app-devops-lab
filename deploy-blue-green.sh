#!/bin/bash
set -e

NEW_VERSION=$1

if [ -z "$NEW_VERSION" ]; then
  echo "No version provided"
  exit 1
fi

BLUE_SERVICE=backend_blue
GREEN_SERVICE=backend_green
NGINX_SERVICE=nginx

echo "Deploying version: $NEW_VERSION"

#ACTIVE=$(docker exec multiservice-app-nginx-1 printenv ACTIVE_BACKEND 2>/dev/null || echo "backend_blue")
ACTIVE=$(docker compose exec -T nginx printenv ACTIVE_BACKEND 2>/dev/null || echo "backend_blue")
echo "Current active backend: $ACTIVE"

if [ "$ACTIVE" = "backend_blue" ]; then
  TARGET=$GREEN_SERVICE
  OLD=$BLUE_SERVICE
else
  TARGET=$BLUE_SERVICE
  OLD=$GREEN_SERVICE
fi

echo "New target backend: $TARGET"

NEW_VERSION=$NEW_VERSION docker compose build --no-cache $TARGET
NEW_VERSION=$NEW_VERSION docker compose up -d $TARGET

echo "Waiting for $TARGET to become healthy..."

for i in {1..10}; do
  STATUS=$(docker inspect --format='{{.State.Health.Status}}' multiservice-app-${TARGET}-1 2>/dev/null || echo "starting")
  echo "Health check attempt $i: $STATUS"

  if [ "$STATUS" = "healthy" ]; then
    echo "$TARGET is healthy!"
    break
  fi

  sleep 5
done

if [ "$STATUS" != "healthy" ]; then
  echo "$TARGET failed health check. Rolling back to $OLD."
  docker compose stop $TARGET
  docker compose rm -f $TARGET
  exit 1
fi

echo "Switching nginx to $TARGET..."
ACTIVE_BACKEND=$TARGET docker compose up -d --force-recreate $NGINX_SERVICE

echo "Post-switch verification..."
sleep 30

POST_STATUS=$(docker inspect --format='{{.State.Health.Status}}' multiservice-app-${TARGET}-1 2>/dev/null || echo "unhealthy")

if [ "$POST_STATUS" != "healthy" ]; then
  echo "Failure after switch. Rolling back..."
  ACTIVE_BACKEND=$OLD docker compose up -d --force-recreate $NGINX_SERVICE
  docker compose stop $TARGET
  docker compose rm -f $TARGET
  exit 1
fi

echo "Stopping $OLD..."
docker compose stop $OLD

echo "ACTIVE_BACKEND=$TARGET" > .env

echo "Deployment successful!"
