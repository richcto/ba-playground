#!/bin/bash
# Build custom Backstage and start with Docker.
# Requires: yarn, docker, docker compose
# Install yarn: npm i -g yarn  (or: corepack enable && corepack prepare yarn@4.4.1 --activate)

set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Installing dependencies (backstage-app)..."
cd backstage-app
yarn install

echo "==> Building backend..."
yarn build:backend

echo "==> Building Docker image..."
cd "$ROOT/backstage"
docker compose -f docker-compose.custom.yml build

echo "==> Starting Backstage..."
docker compose -f docker-compose.custom.yml up -d

echo ""
echo "Backstage is starting at http://localhost:7007"
echo "Stop: docker compose -f docker-compose.custom.yml down"
