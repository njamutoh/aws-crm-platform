#!/bin/bash
# ─────────────────────────────────────────────────────────────
# deploy.sh — single deployment script for all CodeDeploy hooks
#
# Called by appspec.yml with one argument:
#   ./deploy.sh stop      ← BeforeInstall
#   ./deploy.sh pull      ← AfterInstall
#   ./deploy.sh start     ← ApplicationStart
#   ./deploy.sh validate  ← ValidateService
#
# If any command fails, CodeDeploy marks deployment FAILED
# and auto-rolls back to the previous version.
# ─────────────────────────────────────────────────────────────
set -euo pipefail

AWS_REGION=${AWS_REGION:-us-east-1}
ECR_REPO_NAME=${ECR_REPO_NAME:-aws-crm-platform}
SECRETS_NAME=${SECRETS_NAME:-nexus/crm/prod/env}
CONTAINER_NAME="aws-crm-platform"
HEALTH_URL="http://localhost:3000/health"

# Derive ECR URI from instance metadata (no hardcoding)
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPO_NAME"

# ── STOP ─────────────────────────────────────────────────────
stop() {
  echo ">>> [stop] Stopping existing container..."
  if [ "$(docker ps -q -f name=$CONTAINER_NAME)" ]; then
    docker stop $CONTAINER_NAME
    echo "    Container stopped."
  else
    echo "    No running container — skipping."
  fi
  if [ "$(docker ps -aq -f name=$CONTAINER_NAME)" ]; then
    docker rm $CONTAINER_NAME
    echo "    Container removed."
  fi
}

# ── PULL ─────────────────────────────────────────────────────
pull() {
  echo ">>> [pull] Logging in to ECR and pulling image..."
  aws ecr get-login-password --region $AWS_REGION \
    | docker login --username AWS --password-stdin $ECR_URI
  docker pull $ECR_URI:latest
  echo ">>> [pull] Image pulled."
}

# ── START ─────────────────────────────────────────────────────
start() {
  echo ">>> [start] Fetching secrets from Secrets Manager..."
  SECRET_JSON=$(aws secretsmanager get-secret-value \
    --secret-id  "$SECRETS_NAME" \
    --region     "$AWS_REGION"   \
    --query      "SecretString"  \
    --output     text)

  DB_HOST=$(echo     $SECRET_JSON | python3 -c "import sys,json;print(json.load(sys.stdin)['DB_HOST'])")
  DB_USER=$(echo     $SECRET_JSON | python3 -c "import sys,json;print(json.load(sys.stdin)['DB_USER'])")
  DB_PASSWORD=$(echo $SECRET_JSON | python3 -c "import sys,json;print(json.load(sys.stdin)['DB_PASSWORD'])")
  DB_NAME=$(echo     $SECRET_JSON | python3 -c "import sys,json;print(json.load(sys.stdin)['DB_NAME'])")
  JWT_SECRET=$(echo  $SECRET_JSON | python3 -c "import sys,json;print(json.load(sys.stdin)['JWT_SECRET'])")

  echo ">>> [start] Starting container..."
  docker run -d \
    --name $CONTAINER_NAME \
    --restart unless-stopped \
    -p 3000:3000 \
    -e NODE_ENV=production \
    -e PORT=3000 \
    -e DB_HOST="$DB_HOST" \
    -e DB_USER="$DB_USER" \
    -e DB_PASSWORD="$DB_PASSWORD" \
    -e DB_NAME="$DB_NAME" \
    -e DB_PORT=3306 \
    -e JWT_SECRET="$JWT_SECRET" \
    $ECR_URI:latest

  echo ">>> [start] Container started."
}

# ── VALIDATE ──────────────────────────────────────────────────
validate() {
  echo ">>> [validate] Checking app health..."
  for i in $(seq 1 10); do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" $HEALTH_URL || echo "000")
    if [ "$STATUS" = "200" ]; then
      echo "    Health check passed (attempt $i) — HTTP $STATUS"
      exit 0
    fi
    echo "    Attempt $i/10 — HTTP $STATUS — retrying in 3s..."
    sleep 3
  done
  echo "    ERROR: Health check failed. Container logs:"
  docker logs $CONTAINER_NAME --tail 30
  exit 1
}

# ── Router ────────────────────────────────────────────────────
case "${1:-}" in
  stop)     stop     ;;
  pull)     pull     ;;
  start)    start    ;;
  validate) validate ;;
  *)
    echo "Usage: $0 {stop|pull|start|validate}"
    exit 1
    ;;
esac
