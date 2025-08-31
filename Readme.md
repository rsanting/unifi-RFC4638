# UniFi Dream Machine RFC4638 Enabler

[Scripts to enable RFC4638 because it's not currently supported in Unifi](https://community.ui.com/questions/Feature-Request-UDM-Pro-PPPoE-RFC4638-1500-MTU-MRU-for-PPP/b5c1fcf6-bee5-4fc7-ae00-c8ce2bf2e724)

This solution enables RFC4638 support on UniFi Dream Machines, allowing full 1500-byte MTU on PPPoE connections. The UniFi web interface doesn't expose this setting, so this automated enabler monitors and maintains the correct MTU settings.

## Features

- **Automatic MTU monitoring**: Detects when UniFi resets MTU back to 1492
- **Proper layering**: Sets correct MTU for physical interface (1512), VLAN (1508), and PPPoE (1500)
- **Persistent configuration**: Survives firmware updates and reboots
- **Easy installation**: One-command install with auto-detection
- **Configuration file**: Easy to modify settings without editing scripts
- **Debug logging**: Optional detailed logging for troubleshooting
- **Clean uninstall**: Complete removal with configuration restoration

## Quick Install

**Recommended install (download then run):**

```bash
curl -O https://raw.githubusercontent.com/rsanting/unifi-RFC4638/main/install.sh
sudo bash install.sh
```

The installer will:

- Auto-detect your WAN interface and VLAN settings
- Install scripts to `/data/unifi-rfc4638/`
- Create a configuration file with your settings
- Install and start the systemd service
- Show current MTU status

## Requirements

- UniFi Dream Machine (Pro/SE)
- PPPoE connection with RFC4638-capable ISP
- Root access (SSH enabled)

## Configuration

After installation, you can modify settings in `/data/unifi-rfc4638/config.conf`:

```bash
# WAN interface (physical interface connected to modem)
WAN_INTERFACE=eth4

# VLAN ID for PPPoE connection
VLAN_ID=6

# Enable debug logging
DEBUG=false
```

## Management

**View service status:**

```bash
systemctl status unifi-rfc4638.service
```

**View logs:**

```bash
journalctl -u unifi-rfc4638.service -f
```

**Restart service:**

```bash
systemctl restart unifi-rfc4638.service
```

## Uninstall

**Remove everything:**

```bash
sudo bash install.sh --uninstall
```

Or download and run the uninstaller:

```bash
curl -sSL https://raw.githubusercontent.com/rsanting/unifi-RFC4638/main/uninstall.sh | sudo bash
```

## Important Notes

- **Disable MSS Clamping** in the UniFi gateway interface settings
- RFC4638 enabler automatically restarts PPPoE and DNS services when applied
- Your ISP must support RFC4638 for this to work properly
- The service monitors for changes and reapplies RFC4638 automatically

## How It Works

1. **Monitor**: `monitor-mtu.sh` uses `ip monitor` to watch for MTU changes on ppp0
2. **Enable**: When MTU drops to 1492, `rfc4638-mtu.sh` applies RFC4638:
   - Updates `/etc/ppp/peers/ppp0` to use 1500 MTU
   - Sets physical interface to 1512 MTU
   - Sets VLAN interface to 1508 MTU
   - Restarts PPPoE connection
3. **Persist**: Runs as systemd service with auto-restart

## Troubleshooting

**Enable debug logging:**

```bash
sudo sed -i 's/DEBUG=false/DEBUG=true/' /data/unifi-rfc4638/config.conf
sudo systemctl restart unifi-rfc4638.service
journalctl -u unifi-rfc4638.service -f
```

**Check current MTU:**

```bash
cat /sys/class/net/ppp0/mtu
ip link show ppp0
```

**Test RFC4638 is working (1500+ byte MTU):**

Pings of 1472 bytes (1472 bytes of data plus IP headers equals 1500 bytes) should work without being fragmented. Test pings with fragmentation disabled to see if it works.

**From UniFi (Linux):**

```bash
ping -D -s 1472 github.com
```

**From Windows client:**

```cmd
# Test 1500-byte packets (1472 data + 28 headers)
ping -f -l 1472 github.com
```
