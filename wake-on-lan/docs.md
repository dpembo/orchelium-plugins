# Wake on LAN Plugin

Send a Wake-on-LAN (WoL) magic packet to power on a sleeping or shut-down
machine on the local network. Uses Python 3 only — no `wakeonlan` or
`etherwake` package required.

---

## Requirements

- **Python 3** on the Orchelium agent host (pre-installed on virtually all
  Linux distributions).
- The **target machine** must have Wake-on-LAN enabled in its BIOS/UEFI and
  network adapter settings.
- The **agent** must be on the same subnet as the target, or your router/switch
  must forward WoL packets (UDP broadcast) to the target subnet.

---

## Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| **MAC Address** | Yes | — | Target NIC MAC address (`AA:BB:CC:DD:EE:FF`) |
| **Broadcast IP** | No | `255.255.255.255` | UDP broadcast address |
| **UDP Port** | No | `9` | Magic packet port (9 or 7) |
| **Packet Count** | No | `3` | Packets to send (higher count improves reliability) |
| **Wait After Send** | No | `0` | Seconds to wait after sending (for workflow chaining) |

---

## Usage Examples

```yaml
# Wake a server on the local network
mac_address: "AA:BB:CC:DD:EE:FF"

# Wake a machine on a specific subnet
mac_address: "AA:BB:CC:DD:EE:FF"
broadcast_ip: "192.168.10.255"

# Wake then wait 60 s before the next workflow node runs
mac_address: "AA:BB:CC:DD:EE:FF"
wait_seconds: 60
count: 5
```

---

## Notes

- Both `AA:BB:CC:DD:EE:FF` (colon) and `AA-BB-CC-DD-EE-FF` (hyphen) MAC
  formats are accepted. Case-insensitive.
- The plugin sends `count` packets (default 3) to improve reliability on
  busy networks.
- Use `wait_seconds` when the next node in your workflow depends on the
  machine being up (e.g. an SSH, ping, or HTTP-check node).
- WoL only works across subnets if your router/firewall is configured to
  forward directed broadcasts or relay WoL packets.
- Ensure the target NIC is set to **"Wake on Magic Packet"** in BIOS/UEFI
  and operating system power settings.
