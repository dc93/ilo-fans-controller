#!/bin/bash

################################################################################
# iLO Fans Controller - Automated Installation Script
################################################################################
#
# This script automates the installation of iLO Fans Controller on Ubuntu/Debian
#
# Usage:
#   sudo ./install.sh
#
# or with custom options:
#   sudo ./install.sh --path /var/www/html/ilo --port 8080
#
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default configuration
INSTALL_PATH="/var/www/html/ilo-fans-controller"
WEB_USER="www-data"
WEB_GROUP="www-data"
PHP_VERSION="8.1"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --path)
      INSTALL_PATH="$2"
      shift 2
      ;;
    --user)
      WEB_USER="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--path /install/path] [--user www-data]"
      exit 1
      ;;
  esac
done

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Error: This script must be run as root${NC}"
  echo "Please run: sudo $0"
  exit 1
fi

echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        iLO Fans Controller - Installation Script           ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Check system requirements
echo -e "${YELLOW}[1/8]${NC} Checking system requirements..."

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
else
    echo -e "${RED}Error: Cannot detect OS${NC}"
    exit 1
fi

echo "  OS: $OS $VER"

# Check supported OS
case "$OS" in
    *Ubuntu*|*Debian*)
        echo -e "  ${GREEN}✓${NC} Supported OS detected"
        ;;
    *)
        echo -e "  ${YELLOW}⚠${NC}  Warning: This OS may not be fully supported"
        read -p "  Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
        ;;
esac

# Step 2: Update package list
echo -e "\n${YELLOW}[2/8]${NC} Updating package list..."
apt-get update -qq

# Step 3: Install dependencies
echo -e "\n${YELLOW}[3/8]${NC} Installing dependencies..."

PACKAGES=(
    "apache2"
    "php${PHP_VERSION}"
    "php${PHP_VERSION}-curl"
    "php${PHP_VERSION}-ssh2"
    "curl"
    "git"
)

for package in "${PACKAGES[@]}"; do
    if dpkg -l | grep -q "^ii  $package "; then
        echo -e "  ${GREEN}✓${NC} $package already installed"
    else
        echo -e "  Installing $package..."
        apt-get install -y -qq "$package" > /dev/null 2>&1
        echo -e "  ${GREEN}✓${NC} $package installed"
    fi
done

# Step 4: Enable Apache modules
echo -e "\n${YELLOW}[4/8]${NC} Enabling Apache modules..."
a2enmod rewrite > /dev/null 2>&1
a2enmod headers > /dev/null 2>&1
echo -e "  ${GREEN}✓${NC} Apache modules enabled"

# Step 5: Create installation directory
echo -e "\n${YELLOW}[5/8]${NC} Creating installation directory..."
mkdir -p "$INSTALL_PATH"
echo -e "  ${GREEN}✓${NC} Directory created: $INSTALL_PATH"

# Step 6: Download files
echo -e "\n${YELLOW}[6/8]${NC} Downloading iLO Fans Controller..."

# Check if we're in the repository
if [ -f "ilo-fans-controller.php" ]; then
    echo "  Copying files from current directory..."
    cp -r ./* "$INSTALL_PATH/"
else
    echo "  Downloading from GitHub..."
    cd /tmp
    git clone https://github.com/alex3025/ilo-fans-controller.git ilo-temp
    cp -r ilo-temp/* "$INSTALL_PATH/"
    rm -rf ilo-temp
fi

# Rename main file to index.php
if [ -f "$INSTALL_PATH/ilo-fans-controller.php" ]; then
    mv "$INSTALL_PATH/ilo-fans-controller.php" "$INSTALL_PATH/index.php"
fi

echo -e "  ${GREEN}✓${NC} Files downloaded and installed"

# Step 7: Set permissions
echo -e "\n${YELLOW}[7/8]${NC} Setting permissions..."
chown -R $WEB_USER:$WEB_GROUP "$INSTALL_PATH"
chmod -R 755 "$INSTALL_PATH"
chmod 775 "$INSTALL_PATH"  # Directory needs write for presets
touch "$INSTALL_PATH/presets.json"
chown $WEB_USER:$WEB_GROUP "$INSTALL_PATH/presets.json"
chmod 664 "$INSTALL_PATH/presets.json"

# Create data directory for enhanced features
mkdir -p "$INSTALL_PATH/data"
chown $WEB_USER:$WEB_GROUP "$INSTALL_PATH/data"
chmod 775 "$INSTALL_PATH/data"

echo -e "  ${GREEN}✓${NC} Permissions set"

# Step 8: Configuration
echo -e "\n${YELLOW}[8/8]${NC} Configuration..."

if [ ! -f "$INSTALL_PATH/config.inc.php" ] || ! grep -q "your-ilo-address" "$INSTALL_PATH/config.inc.php"; then
    echo "  Config already customized, skipping"
else
    echo ""
    echo "  Please provide your iLO configuration:"
    read -p "  iLO Host (IP address): " ILO_HOST
    read -p "  iLO Username: " ILO_USERNAME
    read -sp "  iLO Password: " ILO_PASSWORD
    echo ""

    # Update config file
    sed -i "s/your-ilo-address/$ILO_HOST/" "$INSTALL_PATH/config.inc.php"
    sed -i "s/your-ilo-username/$ILO_USERNAME/" "$INSTALL_PATH/config.inc.php"
    sed -i "s/your-ilo-password/$ILO_PASSWORD/" "$INSTALL_PATH/config.inc.php"

    echo -e "  ${GREEN}✓${NC} Configuration saved"
fi

# Restart Apache
echo -e "\nRestarting Apache..."
systemctl restart apache2
echo -e "${GREEN}✓${NC} Apache restarted"

# Installation complete
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              Installation Complete!                         ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "iLO Fans Controller has been installed to:"
echo -e "  ${GREEN}${INSTALL_PATH}${NC}"
echo ""
echo -e "Access the web interface at:"
echo -e "  ${GREEN}http://$(hostname -I | awk '{print $1}')$(basename $INSTALL_PATH)/${NC}"
echo ""
echo -e "or locally at:"
echo -e "  ${GREEN}http://localhost/$(basename $INSTALL_PATH)/${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Open the URL above in your browser"
echo "  2. Verify the connection to your iLO"
echo "  3. Create presets for different fan profiles"
echo "  4. (Optional) Set up scheduling with cron"
echo "  5. (Optional) Configure webhooks for notifications"
echo ""
echo -e "${YELLOW}Documentation:${NC}"
echo "  - README.md - Getting started guide"
echo "  - ENHANCED_FEATURES.md - Advanced features"
echo "  - examples/ - Scripts for automation"
echo ""
echo -e "${YELLOW}Troubleshooting:${NC}"
echo "  - Check Apache error logs: sudo tail -f /var/log/apache2/error.log"
echo "  - Verify PHP extensions: php -m | grep -E 'curl|ssh2'"
echo "  - Test iLO connection: curl -k https://YOUR_ILO_IP/redfish/v1"
echo ""
echo -e "Need help? Visit: ${GREEN}https://github.com/alex3025/ilo-fans-controller${NC}"
echo ""
