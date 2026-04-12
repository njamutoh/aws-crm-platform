#!/bin/bash
# ─────────────────────────────────────────────────────────────
# userdata.sh — EC2 instance initialisation (runs once on launch)
# Installs Docker and the CodeDeploy agent on Amazon Linux 2023.
# ─────────────────────────────────────────────────────────────
set -euo pipefail

# ── 1. Update packages ────────────────────────────────────────
dnf update -y

# ── 2. Install and start Docker ───────────────────────────────
dnf install -y docker
systemctl enable docker
systemctl start docker
usermod -aG docker ec2-user

# ── 3. Install CodeDeploy agent ───────────────────────────────
dnf install -y ruby wget

# Use IMDSv2 token (required by launch template metadata options)
TOKEN=$(curl -sf -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
REGION=$(curl -sf -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/placement/region)
cd /tmp
wget -q "https://aws-codedeploy-${REGION}.s3.${REGION}.amazonaws.com/latest/install"
chmod +x ./install
./install auto

systemctl enable codedeploy-agent
systemctl start codedeploy-agent

echo ">>> userdata: Docker and CodeDeploy agent installed successfully."
