#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$(dirname "$SCRIPT_DIR")"

command -v docker &>/dev/null        || { echo "ERROR: docker not found."; exit 1; }
command -v docker compose &>/dev/null || { echo "ERROR: docker compose not found."; exit 1; }

[[ -f .env ]] || { cp .env.template .env; echo "Created .env — fill in values then re-run."; exit 0; }

source .env
for v in DB_PASSWORD RABBITMQ_PASSWORD KEYCLOAK_ADMIN_PASSWORD MINIO_ACCESS_KEY MINIO_SECRET_KEY; do
  [[ -n "${!v:-}" ]] || { echo "ERROR: $v not set in .env"; exit 1; }
done

docker compose pull
docker compose up -d postgres rabbitmq redis minio seq

echo "Waiting for infrastructure..."
for s in postgres rabbitmq redis; do
  for i in $(seq 1 30); do
    docker compose ps "$s" | grep -q "healthy" && break
    sleep 2; [[ $i -eq 30 ]] && { echo "ERROR: $s not healthy"; exit 1; }
  done
  echo "  ✓ $s"
done

echo "Starting Keycloak (may take 90s)..."
docker compose up -d keycloak
for i in $(seq 1 60); do
  docker compose ps keycloak | grep -q "healthy" && break
  sleep 3; [[ $i -eq 60 ]] && { echo "ERROR: Keycloak not healthy"; exit 1; }
done
echo "  ✓ keycloak"

docker compose up -d api
for i in $(seq 1 30); do
  curl -sf http://localhost:80/readyz &>/dev/null && break
  sleep 3; [[ $i -eq 30 ]] && { echo "ERROR: API /readyz failed"; exit 1; }
done
echo "  ✓ api"

docker compose up -d web
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Lex installed!"
echo "  App       : http://localhost"
echo "  Keycloak  : http://localhost:8080  (admin / ${KEYCLOAK_ADMIN_PASSWORD})"
echo "  MinIO     : http://localhost:9001  (${MINIO_ACCESS_KEY})"
echo "  Seq       : http://localhost:8083"
echo "  RabbitMQ  : http://localhost:15672"
echo ""
echo "  ⚠  Change Keycloak admin password immediately."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
