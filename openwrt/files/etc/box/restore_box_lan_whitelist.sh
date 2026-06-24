#!/bin/sh
# Restore the proxy-mode whitelist ipset from the configured whitelist file.

[ -r /lib/functions.sh ] && . /lib/functions.sh

LAN_WHITELIST_FILE="/etc/box/lan_whitelist"
LAN_WHITELIST_SET="box_lan_whitelist"

config_load box 2>/dev/null
config_get LAN_WHITELIST_FILE main lan_whitelist_file "/etc/box/lan_whitelist"
config_get LAN_WHITELIST_SET main lan_whitelist_set "box_lan_whitelist"

if ! command -v ipset >/dev/null 2>&1; then
	echo "box: ipset command not found" >&2
	exit 1
fi

if [ ! -r "$LAN_WHITELIST_FILE" ]; then
	echo "box: missing whitelist file: $LAN_WHITELIST_FILE" >&2
	exit 1
fi

ipset create "$LAN_WHITELIST_SET" hash:net family inet -exist || exit 1
ipset flush "$LAN_WHITELIST_SET" || exit 1

while IFS= read -r line || [ -n "$line" ]; do
	line="${line%%#*}"
	for ip in $line; do
		ipset add "$LAN_WHITELIST_SET" "$ip" -exist 2>/dev/null || \
			echo "box: ignored invalid whitelist entry: $ip" >&2
	done
done < "$LAN_WHITELIST_FILE"

logger -t box-whitelist "restored $LAN_WHITELIST_SET from $LAN_WHITELIST_FILE"
