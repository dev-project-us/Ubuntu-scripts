#!/bin/bash

# =====================================================================
# 🐋 Docker + Docker Compose Installation Script for Ubuntu 24.04 LTS
# Author: Bobby
# Description: Installs Docker Engine, CLI, Buildx, and Compose plugin.
# =====================================================================

set -e
set -o pipefail

echo "=== 🐧 Updating system packages ==="
sudo apt update -y && sudo apt upgrade -y

echo "=== ⚙️ Installing required dependencies ==="
sudo apt install -y ca-certificates curl gnupg lsb-release apt-transport-https software-properties-common

echo "=== 🧩 Setting up Docker’s official GPG key ==="
sudo install -m 0755 -d /etc/apt/keyrings
if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
else
  echo "🔑 Docker GPG key already exists — skipping."
fi

echo "=== 🐳 Adding Docker’s official repository ==="
if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
else
  echo "📂 Docker repository already configured — skipping."
fi

echo "=== 🔄 Updating package lists ==="
sudo apt update -y

echo "=== 📦 Installing Docker Engine, CLI, and plugins ==="
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "=== 🔌 Enabling and starting Docker service ==="
sudo systemctl enable docker
sudo systemctl start docker

echo "=== ✅ Checking Docker status ==="
sudo systemctl status docker --no-pager

echo "=== 🧠 Verifying Docker installation ==="
sudo docker run --rm hello-world || true

echo "=== 👤 Configuring non-root user access ==="
if groups $USER | grep &>/dev/null '\bdocker\b'; then
  echo "✅ User '$USER' is already in the docker group."
else
  sudo usermod -aG docker $USER
  echo "👥 Added '$USER' to the docker group."
  echo "⚠️ Please log out and log back in, or run 'newgrp docker' to apply group changes."
fi

echo "=== 🧩 Checking Docker Compose version ==="
docker compose version || echo "ℹ️ Docker Compose plugin installed but user may need to re-login."

echo "🎉 Installation complete! Docker and Compose are ready to use."
