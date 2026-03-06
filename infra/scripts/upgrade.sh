#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")"
source .env
docker compose pull api web
docker compose run --rm api dotnet Lex.API.dll --migrate-only || { echo "Migration failed — aborting."; exit 1; }
docker compose up -d --no-deps api web
sleep 10
curl -sf http://localhost:80/readyz && echo "✓ Upgrade successful" || { echo "ERROR: /readyz failed after upgrade"; exit 1; }
