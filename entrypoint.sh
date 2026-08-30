#!/bin/sh
set -eu

# ============================================================
#  CLIENT CONFIGURATION
#  Edit this section to customize each client's default binds,
#  sensitivity, graphics, etc.  These are injected into
#  index.html at container startup as ioq3 console commands.
#
#  Format:  '+command', 'arg1', 'arg2'
#  Example: '+set', 'sensitivity', '2.5'
# ============================================================

cat > /tmp/client_cmds.js << 'ENDOFCLIENTCMDS'
    // Each bind must be a single string: ioq3's argv parser only special-cases
    // +set and +connect (consuming the next N args). All other +commands get
    // only argv[i]+1 — subsequent argv elements are NOT consumed as arguments.
    args.push(
        "+bind z \"+forward\"",
        "+bind s \"+back\"",
        "+bind q \"+moveleft\"",
        "+bind d \"+moveright\"",
        "+bind SPACE \"+moveup\"",
        "+bind c \"+movedown\"",
        "+bind SHIFT \"+speed\"",
        "+set", "sensitivity", "5",
        "+set", "m_filter",    "0",
        "+set", "r_fullscreen", "1",
        "+set", "r_colorbits",  "32",
        "+set", "s_volume", "0.8"
    );
ENDOFCLIENTCMDS

# ============================================================
#  DO NOT EDIT BELOW UNLESS YOU KNOW WHAT YOU'RE DOING
# ============================================================

cd /var/www/html

# 1. Inject CLIENT_COMMANDS into index.html before ioq3.callMain(args)
#    Uses a placeholder + awk to safely handle multiline JS injection.
sed -i 's|ioq3.callMain(args);|__INJECT_CLIENT_COMMANDS__\nioq3.callMain(args);|' index.html
awk '
 /__INJECT_CLIENT_COMMANDS__/ {
    while ((getline line < "/tmp/client_cmds.js") > 0) print line;
    next;
  }
  { print }
' index.html > /tmp/index.html
mv /tmp/index.html index.html

# 2. Rewrite the client args so they adapt to whatever origin the browser used:
#    assets come from the page's own host:port, and the game connects over the same
#    port (Apache proxies websocket upgrades to the internal game server on 27960).
sed -i "s/'quakejs:80'/window.location.host/g" index.html
sed -i "s/'quakejs:27960'/window.location.hostname + ':' + (window.location.port || (window.location.protocol === 'https:' ? '443' : '80'))/g" index.html

# 3. Cleanup
rm -f /tmp/client_cmds.js

# 4. Start Apache (serves web assets + WebSocket proxy to game server)
/etc/init.d/apache2 start

# 5. Launch the Quake 3 dedicated server
cd /quakejs
exec node build/ioq3ded.js +set fs_cdn localhost:80 +set fs_game baseq3 +set dedicated 1 +exec server.cfg
