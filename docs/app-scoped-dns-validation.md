# App-scoped DNS validation

This document validates the experimental `dns_hijack_mode="redirect-apps"` path.

## Goal

For a whitelist configuration:

- proxy application DNS must be redirected to the local proxy DNS listener;
- non-proxy application DNS must keep using the Android/system DNS path;
- no Android `VpnService` is involved.

The first implementation supports `redirect`, `tproxy`, `mixed`, and `enhance` network modes.

## Example applications

Proxy whitelist application:

```text
com.yjllq.internet
```

Non-whitelist control application:

```text
com.yujian.ResideMenuDemo
```

## Configure

Put the proxy application in:

```text
/data/adb/box/package.list.cfg
```

Example:

```text
com.yjllq.internet
```

Set in `/data/adb/box/settings.ini`:

```sh
proxy_mode="whitelist"
network_mode="tproxy"
dns_hijack_mode="redirect-apps"
dns_hijack_tcp="true"
dns_hijack_udp="true"
ipv6="true"
```

Install the eBPF matcher:

```sh
/data/adb/box/scripts/box.tool upboxbpf
```

Restart Box.

## Verify UID state

```sh
cat /data/adb/box/run/state/appuid.list
grep -E 'com\.yjllq\.internet|com\.yujian\.ResideMenuDemo' /data/system/packages.list
```

The whitelist app UID must be present in `appuid.list`; the control app UID must not be present.

## Verify eBPF pins

```sh
ls -l /sys/fs/bpf/box/
```

Expected with IPv6 enabled:

```text
box_uid_out4
box_uid_out6
box_app_uid_set
```

If these pins are missing, do not continue DNS leak testing.

## Verify iptables rules

IPv4:

```sh
iptables -t nat -nvL NAT_DNS_HIJACK --line-numbers
iptables -t nat -nvL OUTPUT --line-numbers
```

IPv6:

```sh
ip6tables -t nat -nvL NAT_DNS_HIJACK6 --line-numbers
ip6tables -t nat -nvL OUTPUT --line-numbers
```

In whitelist mode the DNS rule should contain:

```text
-m bpf --object-pinned /sys/fs/bpf/box/box_uid_out4
```

or the IPv6 equivalent, followed by a REDIRECT to the configured local DNS port.

There must be no `NAT_DNS_HIJACK` jump from PREROUTING while `redirect-apps` is active.

## Functional test

Clear counters:

```sh
iptables -t nat -Z NAT_DNS_HIJACK
ip6tables -t nat -Z NAT_DNS_HIJACK6 2>/dev/null || true
```

Then generate fresh DNS queries from `com.yjllq.internet`.

The BPF REDIRECT counter must increase.

Clear the counters again and generate fresh DNS queries from `com.yujian.ResideMenuDemo`.

The BPF REDIRECT counter must remain unchanged.

Use uncached/random hostnames to avoid resolver cache hiding the query.

## Packet capture

If `tcpdump` is available:

```sh
tcpdump -i any -nn '(udp port 53 or tcp port 53 or tcp port 853)'
```

Expected:

- whitelist app/system resolver DNS is redirected locally and the proxy core performs the foreign upstream lookup;
- non-whitelist DNS continues to the current Android/network DNS server.

## Private DNS and browser DoH

Check Android Private DNS:

```sh
settings get global private_dns_mode
settings get global private_dns_specifier
```

A globally configured foreign Private DNS server can make non-whitelist apps appear to use foreign DNS even when Box rules are correct.

Browser DoH uses TCP/UDP 443 rather than port 53. It must be disabled for a pure system-DNS test, or the whitelist application's 443 traffic must remain inside the existing transparent proxy path.

## Rollback

Change:

```sh
dns_hijack_mode="tproxy"
```

or:

```sh
dns_hijack_mode="redirect"
```

then restart Box.

To clear the experimental BPF state manually:

```sh
/data/adb/box/bin/boxbpf --clear
rm -rf /data/adb/box/run/state/ebpf
```

Do not remove unrelated files from `/sys/fs/bpf`.
