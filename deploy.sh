#!/bin/bash

# Exit script on any error
set -e

# --- (1) USER CONFIGURATION - PLEASE FILL THESE VALUES ---
# URL to your private Git repository. Use HTTPS with a Personal Access Token for automation.
# Example: https://<your_username>:<your_pat>@github.com/your_username/kojin.git
GIT_REPO_URL="https://github.com/chient369/trade-bot.git"

# The name of the user that will run the bot.
# On AWS Ubuntu, this is 'ubuntu'. On Google Cloud, it might be your username.
RUN_USER="ubuntu"
# --- END OF CONFIGURATION ---


# --- SCRIPT LOGIC ---
export HOME=/home/$RUN_USER
PROJECT_DIR_NAME="trade-bot" # The name of the folder created by git clone
PROJECT_PATH="$HOME/$PROJECT_DIR_NAME"
LOG_FILE="$HOME/deployment_log.txt"

# Redirect all output to a log file for debugging
exec &> "$LOG_FILE"

echo "===== Starting Automated Bot Deployment (v2) at $(date) ====="

# 1. Update System and Install Dependencies
echo "--> Updating system and installing dependencies (git, python, pip, venv, xvfb)..."
apt-get update -y
# Add xvfb for virtual display
apt-get install -y git python3-pip python3-venv software-properties-common xvfb

# 2. Install Wine to run MetaTrader 5
echo "--> Enabling 32-bit architecture..."
dpkg --add-architecture i386
apt-get update -y
echo "--> Installing Wine (both 64-bit and 32-bit)..."
# Install both to ensure all dependencies are met
apt-get install -y wine64 wine32

# 3. Clone Source Code from Git
echo "--> Cloning repository into $PROJECT_PATH..."
# Run clone as the specified user
sudo -u $RUN_USER git clone "$GIT_REPO_URL" "$PROJECT_PATH"

# 4. Set up Python Virtual Environment
echo "--> Setting up Python virtual environment..."
sudo -u $RUN_USER python3 -m venv "$PROJECT_PATH/venv"
echo "--> Installing Python dependencies..."
sudo -u $RUN_USER "$PROJECT_PATH/venv/bin/pip" install -r "$PROJECT_PATH/bot/requirements.txt"

# 5. Download and Install MetaTrader 5 in a Virtual Display
echo "--> Downloading MT5 Terminal..."
sudo -u $RUN_USER wget https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe -O "$HOME/mt5setup.exe"

echo "--> Installing MT5 via Wine inside a virtual display (Xvfb)..."
# Use xvfb-run to provide a virtual screen for the installer
# This command will run the installer inside the virtual display
sudo -u $RUN_USER xvfb-run --auto-servernum wine "$HOME/mt5setup.exe" /auto

# 6. Prepare Configuration File
echo "--> Creating config.json from template..."
sudo -u $RUN_USER cp "$PROJECT_PATH/bot/config.template.json" "$PROJECT_PATH/bot/config.json"

# 7. Setup Systemd Service to run the Python bot
echo "--> Setting up systemd service..."
SERVICE_NAME="trading_bot"
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME.service"

cat > "$SERVICE_FILE" <<EOL
[Unit]
Description=Python Forex Trading Bot
After=network.target

[Service]
# IMPORTANT: The bot will not work until MT5 Terminal is running and logged in.
User=$RUN_USER
Group=$(id -gn $RUN_USER)
WorkingDirectory=$PROJECT_PATH/bot
ExecStart=$PROJECT_PATH/venv/bin/python main.py
Restart=always
RestartSec=30
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOL

echo "--> Reloading systemd and enabling service..."
systemctl daemon-reload
systemctl enable $SERVICE_NAME

echo "===== SCRIPT FINISHED. MANUAL STEPS REQUIRED! ====="
echo "Deployment script has completed. You must now perform manual steps."
echo "Check the full log at: $LOG_FILE"