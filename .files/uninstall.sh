#!/bin/sh

# =================================================================
# Safe and Complete Uninstaller for the Homebridge LuCI Package
# This script ONLY removes files and settings created by the installer.
# =================================================================

echo "INFO: Starting complete and safe uninstallation of Homebridge..."

# --- Step 1: Stop and disable the service ---
if [ -f /etc/init.d/homebridge ]; then
    echo "INFO: Stopping and disabling Homebridge service..."
    /etc/init.d/homebridge stop || echo "Service was not running."
    /etc/init.d/homebridge disable
fi

# --- Step 2: Uninstall npm packages ---
echo "INFO: Uninstalling global npm packages (this may take a moment)..."
npm uninstall -g homebridge homebridge-config-ui-x

# --- Step 3: Remove files and directories ---
echo "INFO: Removing system files..."
rm -f /etc/init.d/homebridge
rm -f /usr/lib/lua/luci/controller/homebridge.lua # Only removes the homebridge controller
rm -rf /usr/lib/lua/luci/view/homebridge
rm -rf /var/lib/homebridge # Removes Homebridge data directory

# --- Step 4: Remove user ---
if id -u homebridge >/dev/null 2>&1; then
    echo "INFO: Removing 'homebridge' user..."
    userdel homebridge
fi

# --- Step 5: Remove firewall rules ---
echo "INFO: Removing firewall rules..."
uci -q delete firewall.homebridge_ui
uci -q delete firewall.homebridge_bridge
uci commit firewall
/etc/init.d/firewall restart

# --- Step 6: Final Cleanup ---
echo "INFO: Cleaning up cache and temporary files..."
rm -f /tmp/luci-indexcache
rm -f /tmp/homebridge_finalize.sh
rm -f /tmp/homebridge_finalize.log
rm -f nohup.out

echo "-----------------------------------------------------"
echo "SUCCESS: Homebridge has been completely uninstalled."
echo "-----------------------------------------------------"
