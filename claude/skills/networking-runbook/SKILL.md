---
name: networking-runbook
description: Network troubleshooting runbook, CIDR reference, and protocol quick reference. Preloaded into the networking-guru agent.
---

# Networking Runbook

## Troubleshooting Hierarchy

```
1. Physical/Link (L1/L2)  → cable, SFP, duplex, interface errors
2. IP/Routing (L3)        → ping, route table, ARP, ACL
3. Transport (L4)         → port reachability, TCP state, firewall
4. Application (L7)       → DNS, TLS, protocol-specific
```

## Connectivity Toolkit

```bash
# Basic reachability
ping -c 4 <host>
ping -c 4 -s 1400 <host>        # test MTU (large packet)

# Path tracing
traceroute <host>
traceroute -T -p 443 <host>     # TCP traceroute (bypasses ICMP blocks)
mtr --report --report-cycles 20 <host>  # continuous with stats

# Port reachability
nc -zv <host> <port>            # TCP
nc -zvu <host> <port>           # UDP
curl -v telnet://<host>:<port>  # verbose TCP check

# Route selection
ip route get <destination>
ip route show table all

# Listening ports
ss -tlnp                        # TCP listening
ss -ulnp                        # UDP listening
ss -s                           # summary stats

# Packet capture
tcpdump -i eth0 -nn -w /tmp/cap.pcap host <ip> and port <port>
tcpdump -i eth0 -nn 'tcp[tcpflags] & (tcp-rst) != 0'   # RST storm
tcpdump -i eth0 -nn 'icmp'
tcpdump -i eth0 -nn 'tcp and (((ip[2:2] - ((ip[0]&0xf)<<2)) - ((tcp[12]&0xf0)>>2)) != 0)'  # data only

# Interface errors
ip -s link show <iface>         # RX/TX errors, drops
ethtool <iface>                 # speed, duplex, link
ethtool -S <iface>             # driver stats (CRC, fifo errors)
```

## DNS Debugging

```bash
# Full resolution trace
dig +trace <domain>
dig +trace <domain> @8.8.8.8

# Specific record types
dig <domain> A
dig <domain> AAAA
dig <domain> MX
dig <domain> TXT        # SPF, DKIM, ownership
dig <domain> NS
dig <domain> SOA
dig -x <ip>             # reverse DNS

# Quick checks
nslookup <domain> <dns-server>
host <domain>

# Check DNSSEC
dig <domain> +dnssec

# Test internal/split-horizon DNS
dig @<internal-dns-ip> <domain>
dig @<external-dns-ip> <domain>
```

## CIDR Quick Reference

| CIDR | Hosts | Mask | Common Use |
|------|-------|------|-----------|
| /30 | 2 | .252 | P2P links |
| /29 | 6 | .248 | Very small |
| /28 | 14 | .240 | Small segment |
| /27 | 30 | .224 | Small LAN |
| /26 | 62 | .192 | Medium segment |
| /25 | 126 | .128 | Half class C |
| /24 | 254 | .0 | Standard LAN |
| /23 | 510 | 255.254.0 | Two class C |
| /22 | 1022 | 255.252.0 | Four class C |
| /21 | 2046 | 255.248.0 | — |
| /20 | 4094 | 255.240.0 | — |
| /16 | 65534 | 255.0.0 | Large org |

**RFC 1918 Private Ranges:**
- `10.0.0.0/8` — Class A private
- `172.16.0.0/12` — Class B private (172.16-31.x.x)
- `192.168.0.0/16` — Class C private

**Reserved/Special:**
- `100.64.0.0/10` — Carrier-grade NAT (RFC 6598)
- `169.254.0.0/16` — Link-local / APIPA
- `127.0.0.0/8` — Loopback

## TCP State Machine

```
Connection establishment:
Client → SYN →                Server
Client ← SYN-ACK ←           Server
Client → ACK →                Server (ESTABLISHED)

Graceful close (FIN):
Initiator → FIN →             Peer (ESTABLISHED → FIN_WAIT_1)
Initiator ← ACK ←             Peer (FIN_WAIT_2)
Initiator ← FIN ←             Peer (TIME_WAIT)
Initiator → ACK →             Peer (CLOSED after 2×MSL)

RST = immediate teardown, no 4-way handshake
```

**Common TCP issues:**
| Symptom | Likely Cause |
|---------|-------------|
| SYN sent, no response | Firewall drop, host unreachable, wrong port |
| SYN → RST | Port closed on target |
| SYN → SYN-ACK → RST | Stateful firewall asymmetric routing |
| Retransmissions | Packet loss, interface errors, QoS drop |
| Zero window | Receiver buffer full (app slow) |
| TIME_WAIT exhaustion | High connection rate, tune `tcp_fin_timeout` |

## BGP Quick Debug

```bash
# Cisco IOS / IOS-XE
show bgp summary
show bgp neighbors <peer> | include BGP state
show ip bgp <prefix>
debug ip bgp <peer> events    # verbose, use in lab only

# FRRouting (vtysh)
show bgp summary
show bgp neighbors <peer>
show bgp ipv4 unicast <prefix>
show ip route bgp

# BGP stuck in Active state — check:
# 1. TCP 179 reachable: nc -zv <peer> 179
# 2. Correct neighbor IP on both sides
# 3. Correct remote-as
# 4. Firewall allowing TCP 179 from router source IP
# 5. MD5 password mismatch
# 6. eBGP multihop needed?
```

## MTU Troubleshooting

```bash
# Test effective MTU on path (decrease until ping works)
ping -c 1 -M do -s 1472 <host>   # 1472 + 28 headers = 1500
ping -c 1 -M do -s 1400 <host>   # VXLAN: 1500 - 50 = 1450 effective
ping -c 1 -M do -s 8972 <host>   # jumbo frame test (9000 - 28)

# Common MTU values
# Standard Ethernet: 1500
# VXLAN: 1450 (1500 - 50 byte overhead)
# IPsec tunnel: ~1430 (varies by cipher)
# PPPoE: 1492
# Jumbo frames: 9000

# Fix PMTUD black hole (router drops large packets, doesn't send ICMP Frag Needed)
# Force MSS clamp on firewall/router:
# iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
```

## VPN Quick Reference

| Technology | Port | Use Case | Key Config |
|-----------|------|----------|------------|
| IPsec IKEv2 | UDP 500, 4500 | Site-to-site, remote | AES-256-GCM, SHA-256, DH-20 |
| WireGuard | UDP 51820 (default) | Modern VPN, containers | ChaCha20, Curve25519 |
| OpenVPN | UDP 1194 / TCP 443 | Remote access | TLS auth, --tls-crypt |

**IPsec Phase 1 (IKE SA) — recommended:**
```
Encryption: AES-256
Hash:       SHA-256 or SHA-384
DH Group:   20 (384-bit ECP) or 21 (521-bit ECP)
Lifetime:   86400 seconds
```

**IPsec Phase 2 (IPsec SA) — recommended:**
```
Encryption: AES-256-GCM (AEAD, no separate hash needed)
PFS:        Group 20
Lifetime:   3600 seconds
```
