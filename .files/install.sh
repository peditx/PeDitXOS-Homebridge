#!/bin/sh

# ==============================================================================
# Comprehensive and Robust script to install Homebridge and integrate with LuCI.
# Version 11: No longer creates the main menu, only the sub-menu.
# ==============================================================================

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Helper Functions ---
log() {
    echo "INFO: $1"
}

success() {
    echo "SUCCESS: $1"
}

# --- Start Process ---
log "Starting full Homebridge installation and LuCI integration..."
log "WARNING: This process may be time-consuming depending on your router's hardware."

# --- Part 1: Install System Dependencies ---
log "Part 1/4: Installing core dependencies..."
opkg update
opkg install node node-npm git-http avahi-daemon lua shadow-useradd

if ! command -v node >/dev/null 2>&1; then
    echo "ERROR: Node.js installation failed. Please check manually."
    exit 1
fi
success "Core dependencies installed successfully."

# --- Part 2: Install and Configure Homebridge ---
log "Part 2/4: Installing Homebridge and Web UI... (This step can be long)"
npm install -g --unsafe-perm homebridge homebridge-config-ui-x
success "Homebridge and UI installed successfully."

log "Creating 'homebridge' user and required directories..."
HB_DIR="/var/lib/homebridge"
if ! id -u homebridge >/dev/null 2>&1; then
    log "User 'homebridge' not found. Creating it..."
    useradd -r -s /bin/false -d "$HB_DIR" homebridge
else
    log "'homebridge' user already exists, skipping creation."
fi

mkdir -p "$HB_DIR"
chown -R homebridge:homebridge "$HB_DIR"

CONFIG_FILE="$HB_DIR/config.json"
if [ ! -f "$CONFIG_FILE" ]; then
    log "Creating initial config.json..."
    cat <<EOF > "$CONFIG_FILE"
{
    "bridge": {
        "name": "OpenWrt Bridge",
        "username": "0E:00:00:00:00:00",
        "port": 51826,
        "pin": "031-45-154"
    },
    "accessories": [],
    "platforms": [
        {
            "name": "Config",
            "port": 8581,
            "platform": "config"
        }
    ]
}
EOF
    chown homebridge:homebridge "$CONFIG_FILE"
fi
success "Initial Homebridge configuration complete."

# --- Part 3: Create Service and LuCI App Files ---
log "Part 3/4: Creating service and LuCI application files..."

# Create init.d service script
INIT_SCRIPT="/etc/init.d/homebridge"
cat <<'EOF' > "$INIT_SCRIPT"
#!/bin/sh /etc/rc.common
USE_PROCD=1
START=99
STOP=10
PROG="/usr/bin/hb-service"
USER="homebridge"
STORAGE_PATH="/var/lib/homebridge"
start_service() {
    procd_open_instance
    procd_set_param command $PROG run -U $STORAGE_PATH
    procd_set_param user $USER
    procd_set_param stdout 1
    procd_set_param stderr 1
    procd_set_param respawn ${respawn_threshold:-3600} ${respawn_timeout:-5} ${respawn_retry:-5}
    procd_close_instance
}
EOF
chmod +x "$INIT_SCRIPT"

# Create LuCI Controller file for the sub-menu
mkdir -p /usr/lib/lua/luci/controller

# Create Homebridge sub-menu entry under the existing "PeDitXOS Tools"
cat <<'EOF' > /usr/lib/lua/luci/controller/homebridge.lua
module("luci.controller.homebridge", package.seeall)
function index()
    if not nixio.fs.access("/usr/bin/hb-service") then return end
    -- This entry assumes the {"admin", "peditxos"} node already exists.
    local page = entry({"admin", "peditxos", "homebridge"}, template("homebridge/status"), _("Homebridge"), 10)
    page.dependent = true
end
EOF

# Create LuCI View file with Iframe and updated URLs
mkdir -p /usr/lib/lua/luci/view/homebridge
cat <<'EOF' > /usr/lib/lua/luci/view/homebridge/status.htm
<%+header%>
<style type="text/css">
  .custom-orange-btn {
    display: inline-block;
    vertical-align: middle;
    background: linear-gradient(180deg, #ff8c00 0%, #d87500 100%);
    color: #fff !important;
    font-weight: bold;
    padding: 7px 16px;
    border-radius: 5px;
    text-decoration: none;
    border: 1px solid #c06800;
    box-shadow: 0 2px 4px rgba(0,0,0,0.2);
    transition: all 0.2s ease-in-out;
    margin-left: 10px;
  }
  .custom-orange-btn:hover {
    background: linear-gradient(180deg, #ffa500 0%, #e88500 100%);
    box-shadow: 0 4px 8px rgba(0,0,0,0.3);
    transform: translateY(-2px);
  }
  .custom-orange-btn:active {
    transform: translateY(0);
    box-shadow: 0 2px 4px rgba(0,0,0,0.2);
  }
</style>
<h2 name="content">Homebridge Control Panel</h2>
<%
    local status_output = luci.sys.exec("/etc/init.d/homebridge status")
    local is_running = (status_output:find("running") ~= nil)
    local status_text = is_running and "<span style='color:green;font-weight:bold;'>Running</span>" or "<span style='color:red;font-weight:bold;'>Stopped</span>"
    local lan_ip = luci.sys.exec("uci get network.lan.ipaddr"):gsub("\n", "")
    local ui_url = "http://" .. lan_ip .. ":8581"
    if luci.http.formvalue("hb_action") then
        local action = luci.http.formvalue("hb_action")
        if action == "start" or action == "stop" or action == "restart" then
            luci.sys.call("/etc/init.d/homebridge " .. action .. " >/dev/null 2>&1 &")
            luci.sys.call("sleep 2")
            luci.http.redirect(luci.dispatcher.build_url("admin", "peditxos", "homebridge"))
        end
    end
%>
<div class="cbi-map">
    <fieldset class="cbi-section">
        <legend>Service Control</legend>
        <div class="cbi-section-node">
            <div class="cbi-value"><label class="cbi-value-title">Service Status</label><div class="cbi-value-field"><%= status_text %></div></div>
            <div class="cbi-value"><label class="cbi-value-title">Actions</label><div class="cbi-value-field">
                <form style="display: inline-block;" method="post" action="<%=luci.dispatcher.build_url("admin", "peditxos", "homebridge")%>">
                    <button class="cbi-button cbi-button-apply" type="submit" name="hb_action" value="start" <%= is_running and "disabled" or "" %>>Start</button>
                    <button class="cbi-button cbi-button-reset" type="submit" name="hb_action" value="restart" <%= not is_running and "disabled" or "" %>>Restart</button>
                    <button class="cbi-button cbi-button-remove" type="submit" name="hb_action" value="stop" <%= not is_running and "disabled" or "" %>>Stop</button>
                    <a href="<%=ui_url%>" target="_blank" class="custom-orange-btn">Open in New Tab</a>
                </form>
            </div></div>
        </div>
    </fieldset>
    <% if is_running then %>
    <fieldset class="cbi-section"><legend>Homebridge Web Panel</legend>
        <div style="width: 100%; padding: 10px;">
            <iframe id="homebridge_iframe" src="<%=ui_url%>" style="width: 100%; height: 800px; border: 1px solid #ccc; border-radius: 5px;"><p>Your browser does not support iframes.</p></iframe>
        </div>
    </fieldset>
    <% else %>
    <div class="cbi-section-node"><p style="padding: 20px; color: #a00; font-weight: bold;">The Homebridge service is not running. Start it to see the panel.</p></div>
    <% end %>
</div>
<%+footer%>
EOF
success "Service and LuCI files created successfully."

# --- Part 4: Final Activation (Running in Background) ---
log "Part 4/4: Creating background script for final system configuration..."

# Create a finalizer script that will run in the background
cat <<'EOF' > /tmp/homebridge_finalize.sh
#!/bin/sh
# This script runs in the background to prevent the main installer from hanging.

(
    echo "Finalizing Homebridge installation in background..."
    
    # Set firewall rules
    echo "Setting firewall rules..."
    uci -q delete firewall.homebridge_ui
    uci -q delete firewall.homebridge_bridge
    uci add firewall rule
    uci set firewall.@rule[-1].name='Allow Homebridge UI'
    uci set firewall.@rule[-1].src='lan'
    uci set firewall.@rule[-1].proto='tcp'
    uci set firewall.@rule[-1].dest_port='8581'
    uci set firewall.@rule[-1].target='ACCEPT'
    uci rename firewall.@rule[-1]=homebridge_ui
    uci add firewall rule
    uci set firewall.@rule[-1].name='Allow Homebridge Bridge'
    uci set firewall.@rule[-1].src='lan'
    uci set firewall.@rule[-1].proto='tcp udp'
    uci set firewall.@rule[-1].dest_port='51826'
    uci set firewall.@rule[-1].target='ACCEPT'
    uci rename firewall.@rule[-1]=homebridge_bridge
    
    # Commit firewall changes and restart
    echo "Committing and restarting firewall..."
    uci commit firewall
    /etc/init.d/firewall restart
    
    # Enable and start services
    echo "Enabling and starting services..."
    if [ -f /etc/init.d/avahi-daemon ]; then
        /etc/init.d/avahi-daemon enable
        /etc/init.d/avahi-daemon restart
    fi
    /etc/init.d/homebridge enable
    /etc/init.d/homebridge start
    
    # Clear LuCI cache
    echo "Clearing LuCI cache..."
    rm -f /tmp/luci-indexcache
    
    echo "Finalization complete."

) > /tmp/homebridge_finalize.log 2>&1

# Self-delete
rm -- "$0"
EOF

chmod +x /tmp/homebridge_finalize.sh

# Execute the finalizer script in the background, fully detaching it from the terminal.
/tmp/homebridge_finalize.sh >/dev/null 2>&1 &

# --- End of Main Script ---
ROUTER_IP=$(uci get network.lan.ipaddr)
echo ""
echo "==================================================================="
success "Main installation script is complete!"
log "Final system configuration is running in the background."
log "Please wait about one minute, then refresh the LuCI web page."
log "Navigate to 'PeDitXOS Tools' -> 'Homebridge' to see the control panel."
log "You can check the progress in /tmp/homebridge_finalize.log"
log "Direct Panel URL: http://$ROUTER_IP:8581"
echo "==================================================================="
