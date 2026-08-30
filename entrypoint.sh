#!/bin/sh
set -eu

# ============================================================
#  CLIENT CONFIGURATION
#  Edit include/assets/baseq3/client.cfg to customize each
#  client's default binds, sensitivity, graphics, etc.
#  The cfg file is loaded via +exec at container startup.
# ============================================================

# ============================================================
#  DO NOT EDIT BELOW UNLESS YOU KNOW WHAT YOU'RE DOING
# ============================================================

cd /var/www/html

# 1. Rewrite the client args so they adapt to whatever origin the browser used:
#    assets come from the page's own host:port, and the game connects over the same
#    port (Apache proxies websocket upgrades to the internal game server on 27960).
sed -i "s/'quakejs:80'/window.location.host/g" index.html
sed -i "s/'quakejs:27960'/window.location.hostname + ':' + (window.location.port || (window.location.protocol === 'https:' ? '443' : '80'))/g" index.html

# 2. Inject +exec client.cfg into client args so binds/settings are loaded
sed -i "s|var args = \['+set', 'fs_cdn', window.location.host, '+connect'|var args = ['+set', 'fs_cdn', window.location.host, '+exec', 'client.cfg', '+connect'|" index.html

# 2. Start Apache (serves web assets + WebSocket proxy to game server)
/etc/init.d/apache2 start

# 3. Launch the Quake 3 dedicated server
cd /quakejs
exec node build/ioq3ded.js +set fs_cdn localhost:80 +set fs_game baseq3 +set dedicated 1 +exec server.cfg +exec client.cfg
