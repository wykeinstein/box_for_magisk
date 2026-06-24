# Box for OpenWrt

A minimal OpenWrt installer for running **Mihomo (Clash Meta)** as a transparent proxy on OpenWrt 19.07/firewall3 routers.

This repository has been trimmed to keep only the files required for OpenWrt installation and operation. Android/Magisk, KernelSU, APatch, web UI, and multi-core module files have been removed from this OpenWrt-focused tree.

## What is included

- `openwrt/install.sh` - installs OpenWrt dependencies, copies config/service/firewall files, enables the service, and restarts firewall/Mihomo.
- `openwrt/uninstall.sh` - removes the OpenWrt service, UCI config, and firewall hook while preserving user Mihomo config and binary.
- `openwrt/files/etc/box/config.yaml` - default Mihomo config with fake-ip DNS, CN DNS policy, TProxy port, routing mark, and CN/private direct rules.
- `openwrt/files/etc/box/firewall.include` - firewall3/iptables TProxy and DNS hijack rules.
- `openwrt/files/etc/config/box` - UCI settings for binary path, LAN interface, ports, marks, and proxy-server IP bypasses.
- `openwrt/files/etc/init.d/box` - procd service for `/usr/bin/mihomo`.
- `openwrt/README.md` - detailed OpenWrt install/configure/verify/uninstall instructions.

## Install on OpenWrt

Copy this repository to the router, then run:

```sh
cd /path/to/box_for_magisk
sh openwrt/install.sh
```

If `/usr/bin/mihomo` is not already installed, pass a local binary or download URL:

```sh
MIHOMO_BIN=/tmp/mihomo sh openwrt/install.sh
MIHOMO_URL=https://example.com/mihomo-linux-your-arch sh openwrt/install.sh
```

Then edit `/etc/box/config.yaml` and add your proxies or proxy providers.

## Configure proxy-server IP bypass

Add each resolved proxy server IP to `/etc/config/box` so the router does not loop Mihomo's own outbound tunnel back into TProxy:

```sh
uci add_list box.main.server_ip='203.0.113.10'
uci commit box
/etc/init.d/firewall restart
/etc/init.d/box restart
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

See [`openwrt/README.md`](openwrt/README.md) for full details.

## License

This project is licensed under GPL-3.0. See [`LICENSE`](LICENSE).
