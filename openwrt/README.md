# OpenWrt Mihomo mode

This directory makes the project installable on OpenWrt 19.07/firewall3 routers with **Mihomo (Clash Meta)** as the default kernel.

## Modes

Set `/etc/config/box` `option mode` to one of these values:

- `proxy` - transparent proxy mode. Only source IPs in `/etc/box/lan_whitelist` are intercepted and sent to Mihomo.
- `audit` - behavior-audit mode. All routed client traffic is intercepted and sent to Mihomo so Mihomo can log device activity, apply rules, reject domains, and block connections.

Install directly into a mode with `BOX_MODE=proxy sh openwrt/install.sh` or `BOX_MODE=audit sh openwrt/install.sh`. You can also switch later:

```sh
uci set box.main.mode='audit'
uci commit box
/etc/init.d/firewall restart
/etc/init.d/box restart
```

## Install

Copy the repository to the router, then run:

```sh
cd /path/to/box_for_magisk
sh openwrt/install.sh
```

The installer copies:

- `/etc/box/config.yaml` - default Mihomo rule-mode config
- `/etc/config/box` - UCI settings for mode, ports, marks, whitelist paths, and whitelist time control
- `/etc/init.d/box` - procd service that runs `/usr/bin/mihomo -d /etc/box -f /etc/box/config.yaml`
- `/etc/box/firewall.include` - firewall3/iptables TProxy and DNS hijack rules
- `/etc/box/lan_whitelist` - source-IP/CIDR whitelist used by proxy mode
- `/etc/box/reload_lan_whitelist` - hot-reload helper for frequent whitelist edits
- `/etc/box/restore_box_lan_whitelist.sh` and `/etc/box/apply_whitelist_schedule.sh` - proxy-mode time-control helpers

The installer does not bundle a Mihomo binary. If `/usr/bin/mihomo` is missing, install it manually or pass one of these variables:

```sh
MIHOMO_BIN=/tmp/mihomo sh openwrt/install.sh
MIHOMO_URL=https://example.com/mihomo-linux-your-arch sh openwrt/install.sh
```

## Proxy mode whitelist and time control

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

4. Enable optional time control if you want proxy mode disabled during the day and restored later. The defaults flush `box_lan_whitelist` every five minutes from 08:00 through 17:59 and restore it at 18:00:

```sh
uci set box.main.time_control_enabled='1'
uci commit box
/etc/box/apply_whitelist_schedule.sh
```

Adjust the cron expressions if needed:

```sh
uci set box.main.time_control_disable_cron='*/5 8-17 * * *'
uci set box.main.time_control_restore_cron='0 18 * * *'
uci commit box
/etc/box/apply_whitelist_schedule.sh
```

## Audit mode

Audit mode ignores the whitelist and sends all routed client DNS/TCP/UDP traffic to Mihomo. Use Mihomo rules and logs to observe or control behavior, for example `DOMAIN-SUFFIX,example.com,REJECT` to block a site or `DOMAIN-SUFFIX,example.com,DIRECT/PROXY` to steer it. Keep private/special address DIRECT rules before broad proxy rules so LAN and loopback traffic are not forced through a proxy.

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
crontab -l
```

## Uninstall

```sh
sh openwrt/uninstall.sh
```

The uninstall script removes the service, UCI file, firewall include, and whitelist time-control cron entries. It keeps `/etc/box/config.yaml`, `/etc/box/lan_whitelist`, and `/usr/bin/mihomo` so your user config, whitelist, and binary are not deleted accidentally.
