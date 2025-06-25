#!/bin/bash

# This script helps you create a .env file to store your MT5 credentials securely.
# This file will be ignored by Git and will not be committed.

# Check if .env file already exists
if [ -f ".env" ]; then
    echo "An .env file already exists. Do you want to overwrite it? [y/N]"
    read -r response
    # Default to 'No' if user just presses Enter
    if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo "Aborted. The existing .env file was not changed."
        exit 0
    fi
fi

echo "--- Setting up MT5 Environment Variables ---"
echo "Please enter your MetaTrader 5 credentials."
echo "This will create a local .env file."

# Prompt for account details
read -p "Enter your MT5 Account: " mt5_account
read -sp "Enter your MT5 Password: " mt5_password
echo # Move to a new line after the hidden password input
read -p "Enter your MT5 Server: " mt5_server

# Create the .env file using a HEREDOC for clarity
cat > .env << EOL
# Environment variables for the Forex Trading Bot
export MT5_ACCOUNT="${mt5_account}"
export MT5_PASSWORD="${mt5_password}"
export MT5_SERVER="${mt5_server}"
EOL

# Set permissions for the .env file to be readable/writable only by the owner
chmod 600 .env

echo ""
echo "✅ .env file created successfully."
echo "Permissions for .env have been set to read/write for your user only (600)."
echo "You can now run the deploy.sh script, which will automatically use these settings." 