#!/bin/bash
set -Eeuo pipefail

# ============================================================
# deploy.sh
# CodeDeploy lifecycle script for the CRM application.
#
# This script is called by appspec.yml for all lifecycle hooks.
# It decides what to do based on the LIFECYCLE_EVENT variable
# provided by AWS CodeDeploy.
#
# Supported lifecycle events:
#   BeforeInstall    -> stop and remove old container
#   AfterInstall     -> log in to ECR and pull latest image
#   ApplicationStart -> fetch secrets and start new container
#   ValidateService  -> verify health endpoint responds with 200
# ============================================================

# -------------------------
# Configuration
# -------------------------
AWS_REGION="${AWS_REGION:-us-east-1}"
ECR_REPO_NAME="${ECR_REPO_NAME:-crm_app_repo}"
SECRETS_NAME="${SECRETS_NAME:-nexus/crm/prod/env}"

CONTAINER_NAME="${CONTAINER_NAME:-aws-crm-platform}"
CONTAINER_PORT="${CONTAINER_PORT:-3000}"
HOST_PORT="${HOST_PORT:-3000}"
HEALTH_URL="${HEALTH_URL:-http://localhost:3000/health}"

LOG_DIR="/home/ec2-user/deploy"
LOG_FILE="${LOG_DIR}/deploy.log"

mkdir -p "${LOG_DIR}"
touch "${LOG_FILE}"
exec > >(tee -a "${LOG_FILE}") 2>&1

# -------------------------
# Logging helpers
# -------------------------
log() {
  echo "[`date '+%Y-%m-%d %H:%M:%S'`] $1"
}

fail() {
  log "ERROR: $1"
  exit 1
}

trap 'fail "Deployment failed at line ${LINENO}"' ERR

# -------------------------
# Derived values
# -------------------------
AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_NAME}"
IMAGE_URI="${ECR_URI}:latest"

# -------------------------
# Preconditions
# -------------------------
require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

check_prereqs() {
  require_command aws
  require_command docker
  require_command curl
  require_command python3
}

# -------------------------
# Shared helpers
# -------------------------
docker_login() {
  log "Logging in to Amazon ECR..."
  aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${ECR_URI}"
}

get_secret_json() {
  aws secretsmanager get-secret-value     --secret-id "${SECRETS_NAME}"     --region "${AWS_REGION}"     --query 'SecretString'     --output text
}

get_secret_field() {
  local key="$1"
  echo "${SECRET_JSON}" | python3 -c "import sys, json; print(json.load(sys.stdin)['${key}'])"
}

# -------------------------
# Hook actions
# -------------------------
before_install() {
  log "[BeforeInstall] Stopping existing container if present..."

  if [ -n "$(docker ps -q -f "name=${CONTAINER_NAME}")" ]; then
    docker stop "${CONTAINER_NAME}"
    log "Running container stopped."
  else
    log "No running container found."
  fi

  if [ -n "$(docker ps -aq -f "name=${CONTAINER_NAME}")" ]; then
    docker rm "${CONTAINER_NAME}"
    log "Existing container removed."
  else
    log "No existing container to remove."
  fi
}

after_install() {
  log "[AfterInstall] Pulling latest image from ECR..."
  docker_login
  docker pull "${IMAGE_URI}"
  log "Image pulled successfully: ${IMAGE_URI}"
}

application_start() {
  log "[ApplicationStart] Retrieving secrets from Secrets Manager..."
  SECRET_JSON="$(get_secret_json)"

  DB_HOST="$(get_secret_field DB_HOST)"
  DB_USER="$(get_secret_field DB_USER)"
  DB_PASSWORD="$(get_secret_field DB_PASSWORD)"
  DB_NAME="$(get_secret_field DB_NAME)"
  JWT_SECRET="$(get_secret_field JWT_SECRET)"

  log "Starting new container..."
  docker run -d     --name "${CONTAINER_NAME}"     --restart unless-stopped     -p "${HOST_PORT}:${CONTAINER_PORT}"     -e NODE_ENV=production     -e PORT="${CONTAINER_PORT}"     -e DB_HOST="${DB_HOST}"     -e DB_USER="${DB_USER}"     -e DB_PASSWORD="${DB_PASSWORD}"     -e DB_NAME="${DB_NAME}"     -e DB_PORT=3306     -e JWT_SECRET="${JWT_SECRET}"     "${IMAGE_URI}"

  log "Container started successfully."
}

validate_service() {
  log "[ValidateService] Checking application health..."

  for attempt in $(seq 1 10); do
    STATUS="$(curl -s -o /dev/null -w "%{http_code}" "${HEALTH_URL}" || true)"

    if [ "${STATUS}" = "200" ]; then
      log "Health check passed on attempt ${attempt}."
      exit 0
    fi

    log "Attempt ${attempt}/10 failed with HTTP ${STATUS}. Retrying in 3 seconds..."
    sleep 3
  done

  log "Health check failed after 10 attempts."
  log "Last 30 lines of container logs:"
  docker logs "${CONTAINER_NAME}" --tail 30 || true
  exit 1
}

# -------------------------
# Main router
# -------------------------
main() {
  check_prereqs

  local event="${LIFECYCLE_EVENT:-}"
  log "CodeDeploy lifecycle event: ${event:-unset}"

  case "${event}" in
    BeforeInstall)
      before_install
      ;;
    AfterInstall)
      after_install
      ;;
    ApplicationStart)
      application_start
      ;;
    ValidateService)
      validate_service
      ;;
    *)
      fail "Unsupported or missing LIFECYCLE_EVENT: ${event:-unset}"
      ;;
  esac
}

main "$@"
