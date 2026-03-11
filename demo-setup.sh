#!/usr/bin/env bash
# demo-setup.sh — One-command demo environment for buyers
# Usage: bash demo-setup.sh

set -euo pipefail

echo "======================================"
echo "  Unburden — Demo Setup"
echo "======================================"
echo ""

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is not installed. Install Docker Desktop first."
    echo "  → https://docs.docker.com/get-docker/"
    exit 1
fi

if ! docker compose version &> /dev/null; then
    echo "ERROR: Docker Compose v2 is required."
    exit 1
fi

echo "[1/3] Creating backend .env file..."

ENV_FILE="backend/.env"
if [ ! -f "$ENV_FILE" ]; then
    SECRET_KEY=$(openssl rand -hex 32 2>/dev/null || python3 -c "import secrets; print(secrets.token_hex(32))")
    ADMIN_KEY=$(openssl rand -hex 16 2>/dev/null || python3 -c "import secrets; print(secrets.token_hex(16))")

    cat > "$ENV_FILE" <<EOF
APP_SECRET_KEY=${SECRET_KEY}
APP_ENV=development
APP_BASE_URL=http://localhost:3000
REDIS_URL=redis://redis:6379/0
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8000
JWT_EXPIRE_HOURS=168
CHAT_SESSION_MINUTES=15
REQUIRE_EMAIL_VERIFICATION=false
ADMIN_API_KEY=${ADMIN_KEY}
EOF

    echo "  Created $ENV_FILE (email verification disabled for demo)"
    echo "  Admin API Key: ${ADMIN_KEY}"
else
    echo "  $ENV_FILE already exists, skipping."
fi

echo ""
echo "[2/3] Building and starting services..."
docker compose up --build -d

echo ""
echo "[3/3] Waiting for services to be healthy..."
sleep 5

# Check health
for i in {1..12}; do
    if curl -sf http://localhost:8000/health > /dev/null 2>&1; then
        echo ""
        echo "======================================"
        echo "  Demo is ready!"
        echo "======================================"
        echo ""
        echo "  Web App:    http://localhost:3000"
        echo "  API:        http://localhost:8000"
        echo "  Health:     http://localhost:8000/health"
        echo "  API Docs:   http://localhost:8000/docs"
        echo ""
        echo "  To stop:    docker compose down"
        echo "  Logs:       docker compose logs -f"
        echo "======================================"
        exit 0
    fi
    echo "  Waiting... ($i/12)"
    sleep 5
done

echo ""
echo "WARNING: Backend did not respond within 60 seconds."
echo "Check logs with: docker compose logs backend"
exit 1
