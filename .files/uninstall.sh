# Stop and disable the service
/etc/init.d/homebridge stop
/etc/init.d/homebridge disable

# Remove service and LuCI files
rm -f /etc/init.d/homebridge
rm -f /usr/lib/lua/luci/controller/homebridge.lua
rm -rf /usr/lib/lua/luci/view/homebridge


# Uninstall npm packages
echo "Uninstalling npm packages..."
npm uninstall -g homebridge homebridge-config-ui-x

# Remove user and data directory
echo "Removing user and data..."
userdel homebridge
rm -rf /var/lib/homebridge

# Remove firewall rules
echo "Removing firewall rules..."
uci -q delete firewall.homebridge_ui
uci -q delete firewall.homebridge_bridge
uci commit firewall
/etc/init.d/firewall restart

# Final cleanup
echo "Cleaning up cache and log files..."
rm -f /tmp/luci-indexcache
rm -f /tmp/homebridge_finalize.sh
rm -f /tmp/homebridge_finalize.log
rm -f nohup.out

echo "Homebridge has been completely uninstalled."
