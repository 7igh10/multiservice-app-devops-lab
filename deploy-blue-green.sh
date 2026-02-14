#!/bin/bash
set -e

NEW_VERSION=$1

if [ -z "$NEW_VERSION" ]; then
  echo "No version provided"
  exit 1
fi

export NEW_VERSION=$NEW_VERSION
export APP_VERSION=$NEW_VERSION

BLUE_SERVICE=backend_blue
GREEN_SERVICE=backend_green
NGINX_SERVICE=nginx

echo "Deploying version: $NEW_VERSION"

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

# Build and deploy new backend
docker compose build --no-cache $TARGET
docker compose up -d $TARGET

# Wait for health
for i in {1..10}; do
  STATUS=$(docker inspect --format='{{.State.Health.Status}}' multiservice-app-${TARGET}-1 2>/dev/null || echo "starting")
  echo "Health check attempt $i: $STATUS"
  [ "$STATUS" = "healthy" ] && break
  sleep 5
done

if [ "$STATUS" != "healthy" ]; then
  echo "$TARGET failed health check. Rolling back..."
  docker compose stop $TARGET
  docker compose rm -f $TARGET
  exit 1
fi

# Update .env safely (не трогаем секреты)
sed -i '/^ACTIVE_BACKEND=/d' .env 2>/dev/null || true
echo "ACTIVE_BACKEND=$TARGET" >> .env

sed -i '/^APP_VERSION=/d' .env 2>/dev/null || true
echo "APP_VERSION=$NEW_VERSION" >> .env

sed -i '/^NEW_VERSION=/d' .env 2>/dev/null || true
echo "NEW_VERSION=$NEW_VERSION" >> .env

# Force recreate nginx and frontend
docker compose up -d --force-recreate nginx frontend

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

# Stop old backend
docker compose stop $OLD

echo "Deployment successful!"
