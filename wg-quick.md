I've created a comprehensive helper script for working with boringtun-cli. The script is now available at /Users/ryanoates/boringtun/boringtun-helper.sh and has been made executable.

## What the script does

This helper script provides easy commands for:

1. Building boringtun-cli in release or debug mode
2. Building only the boringtun library
3. Installing boringtun-cli using cargo
4. Running boringtun-cli with a specified interface
5. Using boringtun-cli with wg-quick

## Usage

./boringtun-helper.sh [command]

Commands:
  build         - Build boringtun-cli in release mode
  build-debug   - Build boringtun-cli in debug mode
  build-lib     - Build only the boringtun library
  install       - Install boringtun-cli using cargo
  run [iface]   - Run boringtun-cli with the specified interface name
                  (defaults to 'utun' on macOS if not specified)
  wg-quick [config] - Run with wg-quick using the specified config file
  help          - Show this help message


## Examples

To build boringtun-cli:
./boringtun-helper.sh build


To run boringtun-cli with a specific interface:
./boringtun-helper.sh run utun5


To use with wg-quick:
./boringtun-helper.sh wg-quick wg0-client


The script includes colored output for better readability and provides helpful messages throughout the process. It also handles defaults appropriately for macOS (using "utun" as the default interface name).

> explain the use of wg-quick and client settings

# Using wg-quick with BoringTun

wg-quick is a convenient tool that simplifies the setup and management of WireGuard tunnels. When used with BoringTun, it allows you to quickly establish WireGuard connections using configuration files.

## How wg-quick Works

wg-quick reads a configuration file (typically stored in /etc/wireguard/ on Linux or /usr/local/etc/wireguard/ on macOS) and handles:

1. Creating the network interface
2. Setting up IP addresses
3. Configuring routing
4. Applying WireGuard-specific settings
5. Setting up DNS if specified

## Using wg-quick with BoringTun

As mentioned in the README, you can use BoringTun with wg-quick by setting the environment variable WG_QUICK_USERSPACE_IMPLEMENTATION:

bash
sudo WG_QUICK_USERSPACE_IMPLEMENTATION=boringtun-cli WG_SUDO=1 wg-quick up CONFIGURATION


The WG_SUDO=1 environment variable is needed because BoringTun drops privileges by default, which prevents setting fwmark that wg-quick might need.

With the helper script created earlier, you can simplify this to:

bash
./boringtun-helper.sh wg-quick my-config


## Client Configuration Settings

A typical WireGuard client configuration file looks like this:

ini
[Interface]
PrivateKey = YOUR_PRIVATE_KEY
Address = 10.0.0.2/24
DNS = 1.1.1.1, 1.0.0.1

[Peer]
PublicKey = SERVER_PUBLIC_KEY
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = server.example.com:51820
PersistentKeepalive = 25


### Interface Section

• PrivateKey: Your client's private key (keep this secret)
• Address: The IP address assigned to your WireGuard interface
• DNS: DNS servers to use when the tunnel is active (optional)
• MTU: Maximum Transmission Unit size (optional)

### Peer Section

• PublicKey: The server's public key
• AllowedIPs: Traffic destined for these IPs will be routed through the tunnel
  • 0.0.0.0/0, ::/0 routes all traffic through the tunnel (full VPN)
  • For split tunneling, specify only the networks you want to access through the tunnel
• Endpoint: The server's address and port
• PersistentKeepalive: Sends keepalive packets every X seconds (useful for NAT traversal)

## Common Client Configurations

### Full VPN Mode
ini
[Interface]
PrivateKey = YOUR_PRIVATE_KEY
Address = 10.0.0.2/24
DNS = 1.1.1.1, 1.0.0.1

[Peer]
PublicKey = SERVER_PUBLIC_KEY
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = server.example.com:51820
PersistentKeepalive = 25


### Split Tunnel Mode
ini
[Interface]
PrivateKey = YOUR_PRIVATE_KEY
Address = 10.0.0.2/24

[Peer]
PublicKey = SERVER_PUBLIC_KEY
AllowedIPs = 10.0.0.0/24, 192.168.1.0/24
Endpoint = server.example.com:51820
PersistentKeepalive = 25


## Managing Connections

• Start a connection: wg-quick up my-config
• Stop a connection: wg-quick down my-config
• Check status: wg show

When using BoringTun, remember to include the environment variables or use the helper script to manage these connections.