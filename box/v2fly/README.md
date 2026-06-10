## ⚡ V2Ray / v2fly Documentation

🔹 **V2Ray / v2fly**  
📚 Official Docs: [v2fly.org/en_US](https://www.v2fly.org/en_US/)  

## ⚙️ Sample V2Ray Configuration (VMess over WS + TLS)

```json
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": 1080,
      "listen": "127.0.0.1",
      "protocol": "socks",
      "settings": {
        "auth": "noauth",
        "udp": true
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "vmess",
      "settings": {
        "vnext": [
          {
            "address": "example.com",
            "port": 443,
            "users": [
              {
                "id": "abcdefgh-1234-5678-90ab-cdef12345678",
                "alterId": 0,
                "security": "auto"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": {
          "serverName": "example.com",
          "allowInsecure": true
        },
        "wsSettings": {
          "path": "/websocket",
          "headers": {
            "Host": "example.com"
          }
        }
      }
    }
  ]
}
```

## 📱 Using your own VMess JSON in box_for_magisk

If you already have a full V2Ray client JSON (for example exported from OpenWrt), do **not** copy it 1:1 into `box/v2fly/config.json`.

In box_for_magisk, the transparent inbound (`dokodemo-door` on port `9898`) is used by module scripts and should usually be kept as-is. You should mainly replace the **proxy outbound** and keep `direct` / `block` outbounds.

### 1) Set kernel to v2fly

Edit `/data/adb/box/settings.ini`:

```ini
bin_name="v2fly"
network_mode="tproxy"
```

### 2) Edit V2Ray config

Edit `/data/adb/box/v2fly/config.json` and update these fields under outbound tag `proxy`:

- `settings.vnext[0].address`
- `settings.vnext[0].port`
- `settings.vnext[0].users[0].id`
- `settings.vnext[0].users[0].alterId`
- `settings.vnext[0].users[0].security`
- `streamSettings.network` (your sample is `ws`)
- `streamSettings.security` (your sample is `tls`)
- `streamSettings.tlsSettings.serverName`
- `streamSettings.tlsSettings.allowInsecure`
- `streamSettings.wsSettings.path`
- `streamSettings.wsSettings.headers.Host`

Keep inbound tag `tproxy-in` with port `9898` unchanged unless you also change module network settings.

### 3) Example mapping for your two nodes

Node A (`v2ray_client_wlw.json`):

- address: `wlw.wyk.life`
- port: `443`
- id: `764ca471-8487-4baa-a8a9-4a25d85a695f`
- alterId: `10`
- security: `auto`
- ws path: `/`
- ws Host: `wlw.wyk.life`
- tls serverName: `wlw.wyk.life`
- allowInsecure: `true`

Node B (`v2ray_client_bwgqyz.json`):

- address: `bwgqyz.wyk.life`
- port: `443`
- id: `cc6da171-5c76-47a4-9e7f-e790b0c10279`
- alterId: `10`
- security: `auto`
- ws path: `/`
- ws Host: `bwgqyz.wyk.life`
- tls serverName: `bwgqyz.wyk.life`
- allowInsecure: `true`

### 4) Restart module

```sh
su -c /data/adb/box/scripts/box.service stop
su -c /data/adb/box/scripts/box.service start
```

### 5) Quick checks

```sh
su -c /data/adb/box/scripts/box.tool core_status
su -c tail -n 120 /data/adb/box/run/v2fly.log
```

If connection fails, verify server reachability, UUID correctness, and TLS/WS fields (SNI + Host + Path) first.

## 🔍 iptables(TProxy/Redirect) vs TUN mode in box_for_magisk

> This section explains implementation details inside the module, not only conceptual differences.

### A. Core difference in traffic interception path

- **iptables mode** (in BFR naming mainly `tproxy` / `redirect` / `enhance`):
  - Traffic is intercepted by kernel netfilter rules (`iptables`/`ip6tables`) and policy routing.
  - Packets are redirected or transparently proxied to local inbound ports (for v2fly default `tproxy-in:9898`).
  - Proxy core receives original destination through transparent proxy mechanisms (`followRedirect`, `tproxy`).

- **TUN mode** (`network_mode="tun"`, currently used by `sing-box`/`clash` flows):
  - A virtual network interface (TUN) is created by the proxy core.
  - System routes send traffic into this virtual interface first, then the core performs L3/L4 processing and proxy routing.
  - Packet capture happens via virtual NIC instead of primarily relying on per-chain netfilter redirection.

### B. How BFR actually implements them

#### 1) Kernel compatibility and mode constraints

- In `box/scripts/box.iptables`, `xray` and `v2fly` are constrained to `tproxy`; if not, BFR rewrites `network_mode` back to `tproxy`.
- `hysteria` allows only `redirect|tproxy|enhance`.
- `tun/mixed` logic is prepared for `clash` and `sing-box`.

That means with **v2fly in this repo, practical transparent mode is iptables+tproxy path**, not native tun-inbound path by default.

#### 2) iptables path details (tproxy/redirect family)

Implementation points in `box/scripts/box.iptables`:

- Creates dedicated chains such as `BOX_EXTERNAL` / `BOX_LOCAL` (nat table for redirect flows).
- Handles DNS hijacking (e.g., redirect UDP/53 to local DNS listener in certain kernels like clash).
- Maintains intranet whitelist ranges (`intranet`/`intranet6`) to avoid proxying private/reserved/loopback segments.
- Uses fwmark + policy routing variables (`fwmark`, `table`, `pref`) to steer marked packets.
- For tproxy inbound, traffic is sent to local transparent inbound (`dokodemo-door`/`tproxy-in`) where original destination is preserved.

Operationally it is:
1. netfilter match packet;
2. mark/redirect/tproxy action;
3. policy route to local receive path;
4. proxy core outbound decision.

#### 3) tun path details (module behavior)

Implementation points in `box/scripts/box.service` (`prepare_singbox`):

- When `network_mode` is `mixed|tun`, BFR ensures a sing-box `type: "tun"` inbound exists.
- It sets/maintains fields like:
  - `auto_route: true`
  - `auto_redirect: true`
  - `strict_route: true`
  - `include_android_user` and include/exclude package lists.
- In non-tun modes, BFR removes tun inbound and ensures `type: "tproxy"` inbound with configured `tproxy_port`.

So in TUN mode, the core owns route injection and app-level include/exclude is managed through tun inbound fields.

### C. Practical trade-offs (detail)

- **iptables/tproxy advantages**
  - Works well with v2fly/xray transparent inbound model in this module.
  - Lower abstraction, closer to kernel packet path; very controllable with marks/chains/rules.
  - Usually good for full-device transparent proxy when rules are correct.
- **iptables/tproxy caveats**
  - Rule complexity is high (IPv4/IPv6, DNS hijack, whitelist, loop avoidance).
  - Misaligned inbound port or mark/table settings can cause no-network or loops.

- **TUN advantages**
  - Often easier to reason about routing as “all selected traffic enters virtual NIC”.
  - Fine-grained app include/exclude integration (especially in sing-box config generation here).
- **TUN caveats**
  - Depends on tun driver/permissions and core support.
  - MTU/route/stack interactions can affect latency/battery and some app compatibility.

### D. What to choose in your case (using your two VMess configs)

- If you use **v2fly kernel in BFR**: choose `network_mode="tproxy"` and adapt only outbound proxy node fields.
- If you want true tun-style workflow: switch kernel to `sing-box` (or clash with tun-capable config) and use `network_mode="tun"` or `mixed`.
- Keep one change at a time: first ensure node connectivity (UUID/SNI/Host/Path), then adjust mode.

### E. Quick verification commands

```sh
# mode/kernel check
su -c grep -E '^(bin_name|network_mode)=' /data/adb/box/settings.ini

# service + routing rules
su -c /data/adb/box/scripts/box.service status
su -c /data/adb/box/scripts/box.iptables enable

# runtime logs
su -c tail -n 150 /data/adb/box/run/v2fly.log
su -c tail -n 150 /data/adb/box/run/runs.log
```

## 🧭 OpenWrt 19.07.10 adaptation

OpenWrt 19.07.10 is a router environment, so **do not use the Magisk service scripts** (`/data/adb/box/scripts/*`) there. Reuse only the V2Ray/v2fly JSON ideas: one transparent `dokodemo-door` inbound, one VMess outbound, and firewall3/iptables rules that send LAN traffic into the transparent inbound.


### 1) Install v2fly/v2ray on OpenWrt

`box_for_magisk` itself is an Android Magisk/KernelSU/APatch module, so you **do not install the module zip on OpenWrt**. On OpenWrt, install only a v2ray/v2fly core plus the OpenWrt firewall rules below.

1. SSH into the router as `root`.
2. Install runtime dependencies and, if your feed provides it, the v2ray core package:

```sh
opkg update
opkg install ip-full ca-bundle iptables-mod-tproxy iptables-mod-extra kmod-ipt-tproxy kmod-ipt-socket
opkg install v2ray-core v2ray-geoip v2ray-geosite
```

If `v2ray-core`, `v2ray-geoip`, or `v2ray-geosite` is not available in your OpenWrt 19.07 feed, manually place a matching Linux/MIPS or Linux/ARM v2ray/v2fly binary at `/usr/bin/v2ray`, then run:

```sh
chmod 0755 /usr/bin/v2ray
mkdir -p /etc/v2ray
```

If your package already provides `/etc/init.d/v2ray`, keep that init script. If not, create a simple procd init script:

```sh
cat > /etc/init.d/v2ray <<'EOF'
#!/bin/sh /etc/rc.common

START=99
USE_PROCD=1
NAME=v2ray
CONFIG=/etc/v2ray/config.json

start_service() {
  procd_open_instance
  procd_set_param command /usr/bin/v2ray -config "$CONFIG"
  procd_set_param respawn
  procd_set_param stdout 1
  procd_set_param stderr 1
  procd_close_instance
}
EOF
chmod 0755 /etc/init.d/v2ray
```

Then continue with the config and `/etc/firewall.user` rules below.

### 2) Recommended OpenWrt packages

OpenWrt 19.07 uses firewall3 with iptables, not fw4/nftables. Install or provide these components before enabling transparent proxy:

```sh
opkg update
opkg install ip-full ca-bundle iptables-mod-tproxy iptables-mod-extra kmod-ipt-tproxy kmod-ipt-socket
# Install v2ray-core/v2fly from your OpenWrt feed, or place a matching v2ray/v2fly binary manually.
```

`ip-full` is important because policy routing needs `ip rule` and custom routing tables. The `tproxy` kernel/iptables modules are required for UDP transparent proxying.

### 3) OpenWrt v2fly client config

Put this at `/etc/v2ray/config.json` or the config path used by your OpenWrt v2ray init script. This example uses the first node (`wlw.wyk.life`). To use the second node, replace `address`, `id`, `serverName`, and WebSocket `Host` with the `bwgqyz.wyk.life` values listed earlier.

```json
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "tag": "transparent_proxy",
      "port": 12308,
      "listen": "0.0.0.0",
      "protocol": "dokodemo-door",
      "settings": {
        "network": "tcp,udp",
        "followRedirect": true
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      },
      "streamSettings": {
        "sockopt": {
          "tproxy": "tproxy"
        }
      }
    },
    {
      "tag": "http-in",
      "port": 8123,
      "listen": "0.0.0.0",
      "protocol": "http",
      "settings": {
        "allowTransparent": true
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    },
    {
      "tag": "socks-in",
      "port": 10808,
      "listen": "0.0.0.0",
      "protocol": "socks",
      "settings": {
        "auth": "noauth",
        "udp": true
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    }
  ],
  "outbounds": [
    {
      "tag": "proxy",
      "protocol": "vmess",
      "settings": {
        "vnext": [
          {
            "address": "wlw.wyk.life",
            "port": 443,
            "users": [
              {
                "id": "764ca471-8487-4baa-a8a9-4a25d85a695f",
                "alterId": 10,
                "security": "auto"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "sockopt": {
          "mark": 255
        },
        "network": "ws",
        "security": "tls",
        "tlsSettings": {
          "allowInsecure": true,
          "serverName": "wlw.wyk.life"
        },
        "wsSettings": {
          "path": "/",
          "headers": {
            "Host": "wlw.wyk.life"
          }
        }
      },
      "mux": {
        "enabled": false
      }
    },
    {
      "tag": "direct",
      "protocol": "freedom",
      "settings": {
        "domainStrategy": "UseIP"
      },
      "streamSettings": {
        "sockopt": {
          "mark": 255
        }
      }
    },
    {
      "tag": "block",
      "protocol": "blackhole",
      "settings": {
        "response": {
          "type": "http"
        }
      }
    }
  ],
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "type": "field",
        "ip": ["geoip:private", "geoip:cn"],
        "outboundTag": "direct"
      },
      {
        "type": "field",
        "domain": ["geosite:cn"],
        "outboundTag": "direct"
      },
      {
        "type": "field",
        "network": "tcp,udp",
        "outboundTag": "proxy"
      }
    ]
  }
}
```

The `sockopt.mark: 255` on `proxy` and `direct` is intentional: the firewall rules below skip packets already emitted by v2fly so the router does not proxy its own outbound connection again.

### 4) OpenWrt 19.07 firewall3/iptables TProxy rules

Add the following to `/etc/firewall.user` and replace `YOUR_SERVER_IP_1` / `YOUR_SERVER_IP_2` with the resolved A records of your VMess server. Do not put domain names in `iptables -d`; iptables rules match IP addresses.

```sh
# v2fly transparent proxy for OpenWrt 19.07.x (firewall3/iptables)
V2RAY_PORT=12308
V2RAY_MARK=1
V2RAY_TABLE=100
V2RAY_OUT_MARK=255
LAN_IF=br-lan

# Clean old rules on firewall reload.
ip rule del fwmark ${V2RAY_MARK} table ${V2RAY_TABLE} 2>/dev/null
ip route flush table ${V2RAY_TABLE} 2>/dev/null
iptables -t mangle -D PREROUTING -i ${LAN_IF} -j V2RAY 2>/dev/null
iptables -t mangle -D OUTPUT -j V2RAY_LOCAL 2>/dev/null
iptables -t mangle -F V2RAY 2>/dev/null
iptables -t mangle -X V2RAY 2>/dev/null
iptables -t mangle -F V2RAY_LOCAL 2>/dev/null
iptables -t mangle -X V2RAY_LOCAL 2>/dev/null

# Policy routing: packets marked with V2RAY_MARK are delivered locally to v2fly's TProxy socket.
ip rule add fwmark ${V2RAY_MARK} table ${V2RAY_TABLE}
ip route add local 0.0.0.0/0 dev lo table ${V2RAY_TABLE}

iptables -t mangle -N V2RAY
iptables -t mangle -N V2RAY_LOCAL

# Bypass packets generated by v2fly outbound sockets.
iptables -t mangle -A V2RAY -m mark --mark ${V2RAY_OUT_MARK} -j RETURN
iptables -t mangle -A V2RAY_LOCAL -m mark --mark ${V2RAY_OUT_MARK} -j RETURN

# Bypass your proxy server IPs; otherwise the tunnel connection can loop back into itself.
iptables -t mangle -A V2RAY -d YOUR_SERVER_IP_1 -j RETURN
iptables -t mangle -A V2RAY -d YOUR_SERVER_IP_2 -j RETURN
iptables -t mangle -A V2RAY_LOCAL -d YOUR_SERVER_IP_1 -j RETURN
iptables -t mangle -A V2RAY_LOCAL -d YOUR_SERVER_IP_2 -j RETURN

# Bypass local, LAN, multicast, and reserved ranges.
for subnet in \
  0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 \
  169.254.0.0/16 172.16.0.0/12 192.168.0.0/16 \
  224.0.0.0/4 240.0.0.0/4; do
  iptables -t mangle -A V2RAY -d ${subnet} -j RETURN
  iptables -t mangle -A V2RAY_LOCAL -d ${subnet} -j RETURN
done

# LAN clients: TCP and UDP go into dokodemo-door TProxy inbound.
iptables -t mangle -A V2RAY -p tcp -j TPROXY --on-port ${V2RAY_PORT} --tproxy-mark ${V2RAY_MARK}
iptables -t mangle -A V2RAY -p udp -j TPROXY --on-port ${V2RAY_PORT} --tproxy-mark ${V2RAY_MARK}
iptables -t mangle -A PREROUTING -i ${LAN_IF} -j V2RAY

# Router-originated TCP traffic. Keep this only if the router itself should also use the proxy.
iptables -t mangle -A V2RAY_LOCAL -p tcp -j MARK --set-mark ${V2RAY_MARK}
iptables -t mangle -A OUTPUT -j V2RAY_LOCAL
```

For router-originated UDP, prefer letting the router use normal DNS/NTP directly unless you fully understand local UDP transparent proxying. LAN-client UDP is already handled by the PREROUTING TProxy path above.

### 5) Start and verify on OpenWrt 19.07.10

```sh
/etc/init.d/v2ray enable
/etc/init.d/v2ray restart
/etc/init.d/firewall restart

logread -e v2ray
ip rule show
ip route show table 100
iptables -t mangle -vnL V2RAY
iptables -t mangle -vnL V2RAY_LOCAL
```

If clients have no network after enabling this, first check that `YOUR_SERVER_IP_*` is correct and bypassed, then check whether `iptables-mod-tproxy` / `kmod-ipt-tproxy` is installed and whether the LAN interface is really `br-lan`.

