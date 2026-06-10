#!/bin/sh
set -eu

SRC_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR="${SRC_DIR}/files"

if [ ! -f /etc/openwrt_release ]; then
	echo "This installer is intended for OpenWrt." >&2
	exit 1
fi

opkg update
opkg install ca-bundle ip-full ipset iptables iptables-mod-ipset iptables-mod-tproxy iptables-mod-extra kmod-ipt-ipset kmod-ipt-tproxy kmod-ipt-socket

mkdir -p /etc/box /etc/config /etc/init.d
cp -f "${ROOT_DIR}/etc/box/config.yaml" /etc/box/config.yaml
cp -f "${ROOT_DIR}/etc/box/firewall.include" /etc/box/firewall.include
cp -f "${ROOT_DIR}/etc/box/reload_lan_whitelist" /etc/box/reload_lan_whitelist
[ -f /etc/box/lan_whitelist ] || cp -f "${ROOT_DIR}/etc/box/lan_whitelist" /etc/box/lan_whitelist
cp -f "${ROOT_DIR}/etc/config/box" /etc/config/box
cp -f "${ROOT_DIR}/etc/init.d/box" /etc/init.d/box
chmod 0644 /etc/box/config.yaml /etc/config/box /etc/box/lan_whitelist
chmod 0755 /etc/box/firewall.include /etc/box/reload_lan_whitelist /etc/init.d/box

if [ -n "${MIHOMO_BIN:-}" ]; then
	cp -f "$MIHOMO_BIN" /usr/bin/mihomo
	chmod 0755 /usr/bin/mihomo
elif [ -n "${MIHOMO_URL:-}" ]; then
	tmp="/tmp/mihomo-download.$$"
	if command -v curl >/dev/null 2>&1; then
		curl -L --fail -o "$tmp" "$MIHOMO_URL"
	else
		wget -O "$tmp" "$MIHOMO_URL"
	fi
	cp -f "$tmp" /usr/bin/mihomo
	chmod 0755 /usr/bin/mihomo
	rm -f "$tmp"
elif [ ! -x /usr/bin/mihomo ]; then
	cat >&2 <<'MSG'
Mihomo binary was not found at /usr/bin/mihomo.
Install it with one of these methods, then re-run this installer or start the service:
  MIHOMO_BIN=/tmp/mihomo ./openwrt/install.sh
  MIHOMO_URL=https://example/mihomo-linux-xxx ./openwrt/install.sh
MSG
fi

if ! grep -q '^\. /etc/box/firewall.include$' /etc/firewall.user 2>/dev/null; then
	printf '\n# box_for_magisk OpenWrt Mihomo transparent proxy\n. /etc/box/firewall.include\n' >> /etc/firewall.user
fi

/etc/init.d/box enable
/etc/init.d/firewall restart
if [ -x /usr/bin/mihomo ]; then
	/etc/init.d/box restart
else
	echo "Installed OpenWrt files. Put mihomo at /usr/bin/mihomo, then run: /etc/init.d/box restart" >&2
fi
