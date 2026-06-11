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
- `/etc/config/box` - UCI settings for ports, marks, and whitelist paths
- `/etc/init.d/box` - procd service that runs `/usr/bin/mihomo -d /etc/box -f /etc/box/config.yaml`
- `/etc/box/firewall.include` - firewall3/iptables TProxy and DNS hijack rules
- `/etc/box/lan_whitelist` - source-IP/CIDR whitelist for interception
- `/etc/box/reload_lan_whitelist` - hot-reload helper for frequent whitelist edits

The installer does not bundle a Mihomo binary. If `/usr/bin/mihomo` is missing, install it manually or pass one of these variables:

```sh
MIHOMO_BIN=/tmp/mihomo sh openwrt/install.sh
MIHOMO_URL=https://example.com/mihomo-linux-your-arch sh openwrt/install.sh
```

## Configure

1. Edit `/etc/box/config.yaml` and add your proxies or proxy-providers.
2. Add the client source IPs that should enter transparent proxying to `/etc/box/lan_whitelist`. These IPs are matched on any ingress interface, not only `br-lan`:

```sh
cat >> /etc/box/lan_whitelist <<'EOF'
192.168.1.100
192.168.1.128/25
EOF
```

3. Hot-reload whitelist changes whenever you add or remove entries:

```sh
/etc/box/reload_lan_whitelist
```

4. Restart services only when changing Mihomo config or firewall/UCI settings:

```sh
/etc/init.d/box restart
/etc/init.d/firewall restart
```

Proxy-server/node IP bypass lists are no longer used. Mihomo's own outbound traffic is bypassed by its `routing-mark`, which prevents re-entry without excluding node destination IPs for clients.

## Verify

```sh
logread -e box
logread -e mihomo
ip rule show
ip route show table 100
iptables -t nat -vnL PREROUTING
iptables -t mangle -vnL BOX_MIHOMO
ipset list box_lan_whitelist
```

## Uninstall

```sh
sh openwrt/uninstall.sh
```

The uninstall script removes the service, UCI file, and firewall include. It keeps `/etc/box/config.yaml`, `/etc/box/lan_whitelist`, and `/usr/bin/mihomo` so your user config, whitelist, and binary are not deleted accidentally.
