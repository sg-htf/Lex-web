#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")"
source .env
DIR="backups/$(date '+%Y%m%d_%H%M%S')"
mkdir -p "$DIR"
docker compose exec -T postgres pg_dump -U lex lex | gzip > "$DIR/postgres.sql.gz"
curl -su "lex:${RABBITMQ_PASSWORD}" http://localhost:15672/api/definitions > "$DIR/rabbitmq.json"
echo "✓ Backup: $DIR  ($(du -sh "$DIR" | cut -f1))"
