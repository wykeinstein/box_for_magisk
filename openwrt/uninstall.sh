#!/bin/sh
set -eu

/etc/init.d/box stop 2>/dev/null || true
/etc/init.d/box disable 2>/dev/null || true

if [ -f /etc/firewall.user ]; then
	sed -i '/box_for_magisk OpenWrt Mihomo transparent proxy/d;/^\. \/etc\/box\/firewall\.include$/d' /etc/firewall.user
fi

rm -f /etc/init.d/box /etc/config/box /etc/box/firewall.include /etc/box/reload_lan_whitelist
# Keep /etc/box/config.yaml, /etc/box/lan_whitelist, and /usr/bin/mihomo by default so user data is not destroyed.
/etc/init.d/firewall restart 2>/dev/null || true
