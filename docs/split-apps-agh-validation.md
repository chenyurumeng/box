# split-apps + Dual AdGuard Home 验证指南

## 目标

`dns_hijack_mode="split-apps"`：

- 白名单应用：普通流量由 Box/Mihomo 代理；DNS 进入 Foreign AGH :5592。
- 非白名单应用：普通流量 DIRECT；DNS 进入 Domestic AGH :5591。
- Foreign AGH 使用国外 DoH DIRECT。
- Domestic AGH 使用国内 DoH DIRECT。
- 两边都获得 AdGuard Home 广告过滤、缓存和统计。

## Box 设置

```ini
proxy_mode="whitelist"
network_mode="tproxy"

dns_hijack_mode="split-apps"
dns_hijack_tcp="true"
dns_hijack_udp="true"

domestic_dns_port="5591"
foreign_dns_port="5592"
foreign_dns_fallback_port="1053"
foreign_dns_fail_port="65534"

ipv6="true"
performance_mode="false"
```

`package.list.cfg` 中只放需要代理/国外 DNS 的应用，例如：

```
com.yjllq.internet
```

## AGH 要求

AdGuardHomeForRoot 使用 `integration_mode=box-dual`：

- Domestic :5591 / Web :3000
- Foreign :5592 / Web :3001
- AGH 自己不安装 iptables
- AGH 进程身份 root:net_raw

检查：

```sh
/data/adb/agh/scripts/tool.sh status
ss -lnup | grep -E ':5591|:5592'
```

## 正常规则

```sh
iptables -t nat -nvL NAT_DNS_HIJACK --line-numbers
```

预期顺序：

1. Box 核心旁路
2. AGH root:net_raw DNS self-bypass
3. eBPF 白名单 TCP/UDP 53 -> 5592
4. 剩余 TCP/UDP 53 -> 5591

普通透明代理链中还应存在 root:net_raw -> RETURN，从而让 AGH 的 DoH 上游整体 DIRECT。

## A/B 测试

清计数：

```sh
iptables -t nat -Z NAT_DNS_HIJACK
```

白名单浏览器访问随机域名，再查看规则计数。eBPF ->5592 应增加。

清零后使用非白名单应用。eBPF ->5592 不应增加；5591 catch-all 应增加。

## DNS 后端测试

```sh
dig @127.0.0.1 -p 5591 www.baidu.com A +stats
dig @127.0.0.1 -p 5592 www.google.com A +stats
```

检查 AGH Web UI：

- http://127.0.0.1:3000 国内实例
- http://127.0.0.1:3001 国外实例

## 故障演练

### Domestic AGH 故障

```sh
/data/adb/agh/scripts/tool.sh stop-domestic
sleep 6
iptables -t nat -nvL NAT_DNS_HIJACK --line-numbers
```

预期：5591 catch-all 消失；非白名单恢复 Android 系统 DNS；白名单仍走 5592。

### Foreign AGH 故障

```sh
/data/adb/agh/scripts/tool.sh stop-foreign
sleep 6
iptables -t nat -nvL NAT_DNS_HIJACK --line-numbers
```

预期：白名单 eBPF 目标从 5592 切到 1053；非白名单仍走 5591。

### Foreign AGH + Mihomo DNS 同时故障

Foreign 5592 与 Mihomo 1053 都不监听时，白名单 eBPF 目标应为本地 65534，fail-closed；绝不能落到 5591 或系统 DNS。非白名单继续正常。

## 停止 Box 恢复

直接执行：

```sh
/data/adb/box/scripts/box.service stop
```

本 Fork 已修改为先调用 `box.iptables disable` 再停止核心，必须恢复 Android 系统 DNS。

## 独立紧急救援

即使 Box/Mihomo/AGH 主进程异常：

```sh
su -c /data/adb/box/scripts/dns-rescue.sh
```

它只删除 Box 自己的 DNS hook，包括：

- NAT_DNS_HIJACK
- NAT_DNS_HIJACK_NEXT
- NAT_DNS_FORWARD
- IPv6 BOX_DNS6_REJECT

不会删除 Android/ColorOS 系统 BPF。

## IPv6

若设备缺少 ip6tables NAT，split-apps 使用 IPv6 TCP/UDP 53 REJECT，让 DnsResolver 快速退回 IPv4 DNS；IPv6 普通网页流量不受影响。

## Private DNS / DoH

首轮验证：

```sh
settings put global private_dns_mode off
```

浏览器 Secure DNS 也关闭。否则 DoT/DoH 不是 53 端口，可能绕过 AGH。
