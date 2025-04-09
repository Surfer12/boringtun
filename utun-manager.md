# utun Interface Manager for BoringTun and Cloudflare WARP

This document provides information about managing utun interfaces on macOS when working with BoringTun and Cloudflare WARP.

## What are utun interfaces?

"utun" interfaces are virtual network tunnel interfaces on macOS (similar to "tun" interfaces on Linux). They are used to create virtual network adapters that can route traffic through various tunneling protocols, including WireGuard.

## BoringTun and utun interfaces

BoringTun is a userspace implementation of the WireGuard protocol that creates and manages utun interfaces on macOS. When you run BoringTun, it creates a utun interface that can be used to route traffic through the WireGuard tunnel.

### Creating a utun interface with BoringTun

To create a utun interface with BoringTun, you can use the following command:

```bash
sudo boringtun-cli --foreground utun
```

This will create a utun interface with the next available number (e.g., utun1, utun2, etc.). If you want to specify a specific utun interface number, you can use:

```bash
sudo boringtun-cli --foreground utun5
```

### Listing utun interfaces

To list all utun interfaces on your system:

```bash
ifconfig | grep -A1 "utun"
```

### Checking utun interface status

To check the status of a specific utun interface:

```bash
ifconfig utun1
```

## Cloudflare WARP and utun interfaces

Cloudflare WARP uses BoringTun as its underlying WireGuard implementation and creates utun interfaces when connected.

### Managing WARP connections

You can use the `warp-cli` command to manage Cloudflare WARP connections:

```bash
# Connect to WARP
warp-cli connect

# Disconnect from WARP
warp-cli disconnect

# Check WARP status
warp-cli status
```

### Identifying WARP utun interfaces

When WARP is connected, it creates a utun interface. You can identify which utun interface is being used by WARP by checking the routing table:

```bash
netstat -nr | grep utun
```

## Using the boringtun-helper.sh script

The `boringtun-helper.sh` script provides convenient commands for managing BoringTun and WARP:

```bash
# Show status of all utun interfaces and running BoringTun instances
./boringtun-helper.sh status

# Connect to WARP
./boringtun-helper.sh warp-connect

# Disconnect from WARP
./boringtun-helper.sh warp-disconnect

# Show WARP status
./boringtun-helper.sh warp-status
```

## Troubleshooting utun interfaces

### Interface already exists

If you get an error that the interface already exists, you can try specifying a different utun number:

```bash
sudo boringtun-cli --foreground utun2
```

### Permission issues

BoringTun requires administrative privileges to create utun interfaces. Always use `sudo` when running BoringTun directly.

### Removing stale interfaces

Sometimes utun interfaces can remain after a program crashes. You can remove them by rebooting or by using the following command:

```bash
sudo ifconfig utun1 down
```

### Checking logs

To check system logs related to utun interfaces:

```bash
log show --predicate 'subsystem == "com.apple.networking.utun"' --last 30m
```

## Advanced Configuration

### Setting up routing

To route traffic through a utun interface, you need to configure the routing table:

```bash
# Route all traffic through utun1
sudo route add -net 0.0.0.0/0 -interface utun1
```

### Configuring WireGuard

After creating a utun interface with BoringTun, you can configure it using the `wg` command:

```bash
sudo wg set utun1 private-key /path/to/private-key peer PEER_PUBLIC_KEY allowed-ips 0.0.0.0/0 endpoint ENDPOINT:PORT
```

### Using with wg-quick

You can use BoringTun with wg-quick by setting the appropriate environment variables:

```bash
sudo WG_QUICK_USERSPACE_IMPLEMENTATION=boringtun-cli WG_SUDO=1 wg-quick up /path/to/config
```

## References

- [BoringTun GitHub Repository](https://github.com/cloudflare/boringtun)
- [WireGuard Documentation](https://www.wireguard.com/quickstart/)
- [Cloudflare WARP Documentation](https://developers.cloudflare.com/warp-client/)
