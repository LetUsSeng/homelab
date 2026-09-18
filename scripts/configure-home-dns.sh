#!/usr/bin/env bash
set -euo pipefail

# Point this laptop's home wifi profile at pihole. NetworkManager keeps DNS per
# connection profile, so other networks (airports, hotels, ...) keep their own DHCP DNS.
#   usage: ./scripts/configure-home-dns.sh [profile] [pihole-ip]
PROFILE="${1:-Home_Internet}"
PIHOLE_IP="${2:-10.0.0.101}"

if ! nmcli -t -f NAME connection show | grep -Fxq "$PROFILE"; then
	echo "no NetworkManager profile named '$PROFILE'" >&2
	exit 1
fi

# NOTE:
# ipv4.ignore-auto-dns stays "no" so the router's DHCP DNS (Comcast) is kept after pihole
# as a fallback. glibc only moves to the next nameserver on a timeout, so pihole answers
# normally. The router's IPv6 RA DNS is ignored: it only got cut by glibc's 3-nameserver
# limit and would otherwise bypass pihole whenever it lands in a slot.
current="$(nmcli -g ipv4.dns,ipv4.ignore-auto-dns,ipv6.ignore-auto-dns connection show "$PROFILE")"
wanted="$(printf '%s\n%s\n%s' "$PIHOLE_IP" no yes)"

if [[ "$current" == "$wanted" ]]; then
	echo "$PROFILE already uses pihole ($PIHOLE_IP), nothing to change"
else
	nmcli connection modify "$PROFILE" \
		ipv4.dns "$PIHOLE_IP" \
		ipv4.ignore-auto-dns no \
		ipv6.ignore-auto-dns yes

	# NOTE:
	# Modified settings only take effect on (re)activation, which briefly reconnects wifi.
	# Skip it when the profile isn't active; the settings apply next time it connects.
	if nmcli -t -f NAME connection show --active | grep -Fxq "$PROFILE"; then
		nmcli connection up "$PROFILE"
	fi
fi

nmcli -f ipv4.dns,ipv4.ignore-auto-dns,ipv6.ignore-auto-dns connection show "$PROFILE"
grep '^nameserver' /etc/resolv.conf
