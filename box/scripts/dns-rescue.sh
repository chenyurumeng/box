#!/system/bin/sh
# Emergency DNS recovery for Box split DNS.
# This script intentionally does not source Box runtime state and does not
# require Mihomo/AdGuardHome to be running.  It only removes Box-owned DNS
# hooks so Android's system resolver can take over again.

IPT="iptables -w 10"
IP6T="ip6tables -w 10"

cleanup_v4() {
  for chain in NAT_DNS_HIJACK NAT_DNS_FORWARD MIHOMO_DNS_EXTERNAL MIHOMO_DNS_LOCAL; do
    $IPT -t nat -D OUTPUT -j "$chain" >/dev/null 2>&1 || true
    $IPT -t nat -D PREROUTING -j "$chain" >/dev/null 2>&1 || true
    $IPT -t nat -F "$chain" >/dev/null 2>&1 || true
    $IPT -t nat -X "$chain" >/dev/null 2>&1 || true
  done
}

cleanup_v6() {
  for chain in NAT_DNS_HIJACK6 NAT_DNS_FORWARD6; do
    $IP6T -t nat -D OUTPUT -j "$chain" >/dev/null 2>&1 || true
    $IP6T -t nat -D PREROUTING -j "$chain" >/dev/null 2>&1 || true
    $IP6T -t nat -F "$chain" >/dev/null 2>&1 || true
    $IP6T -t nat -X "$chain" >/dev/null 2>&1 || true
  done

  $IP6T -t filter -D OUTPUT -j BOX_DNS6_REJECT >/dev/null 2>&1 || true
  $IP6T -t filter -F BOX_DNS6_REJECT >/dev/null 2>&1 || true
  $IP6T -t filter -X BOX_DNS6_REJECT >/dev/null 2>&1 || true
}

cleanup_v4
cleanup_v6

echo "Box DNS hooks removed. Android system DNS is active again."
