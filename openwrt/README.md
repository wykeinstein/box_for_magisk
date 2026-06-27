# OpenWrt Mihomo mode

This directory makes the project installable on OpenWrt 19.07/firewall3 routers with **Mihomo (Clash Meta)** as the default kernel.

## Install

Copy the repository to the router, then run:

```sh
cd /path/to/box_for_magisk
sh openwrt/install.sh
```

The installer copies:

- `/etc/box/config.yaml` - default Mihomo rule-mode config
- `/etc/config/box` - UCI settings for ports, LAN interface, marks, and bypass IPs
- `/etc/init.d/box` - procd service that runs `/usr/bin/mihomo -d /etc/box -f /etc/box/config.yaml`
- `/etc/box/firewall.include` - firewall3/iptables TProxy and DNS hijack rules

The installer does not bundle a Mihomo binary. If `/usr/bin/mihomo` is missing, install it manually or pass one of these variables:

```sh
MIHOMO_BIN=/tmp/mihomo sh openwrt/install.sh
MIHOMO_URL=https://example.com/mihomo-linux-your-arch sh openwrt/install.sh
```

## Configure

1. Edit `/etc/box/config.yaml` and add your proxies or proxy-providers.
2. Add each proxy server IP to `/etc/config/box` to prevent loops:

```sh
uci add_list box.main.server_ip='203.0.113.10'
uci commit box
```

3. Restart services:

```sh
/etc/init.d/box restart
/etc/init.d/firewall restart
```

## Verify

```sh
logread -e box
logread -e mihomo
ip rule show
ip route show table 100
iptables -t nat -vnL PREROUTING
iptables -t mangle -vnL BOX_MIHOMO
```

## Uninstall

```sh
sh openwrt/uninstall.sh
```

The uninstall script removes the service, UCI file, and firewall include. It keeps `/etc/box/config.yaml` and `/usr/bin/mihomo` so your user config and binary are not deleted accidentally.
