#!/bin/bash
# utun-manager.sh - Helper script for managing WireGuard connections using BoringTun on macOS
# Created: 2025-04-09

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Default locations
CONFIG_DIR="${CONFIG_DIR:-$HOME/.wireguard}"
LOG_DIR="${LOG_DIR:-$HOME/.wireguard/logs}"
BORINGTUN_BIN="boringtun-cli"

# Create necessary directories
mkdir -p "$CONFIG_DIR" "$LOG_DIR"

# Function to display usage information
show_help() {
    echo -e "${BLUE}BoringTun utun Connection Manager${NC}"
    echo "Usage: ./utun-manager.sh [command] [options]"
    echo ""
    echo "Commands:"
    echo "  start <config>     - Start a WireGuard connection using the specified config"
    echo "  stop <interface>   - Stop a WireGuard connection on the specified interface"
    echo "  status             - Show status of all WireGuard interfaces"
    echo "  list               - List available configuration files"
    echo "  create <name>      - Create a new configuration file template"
    echo "  help               - Show this help message"
    echo ""
    echo "Options:"
    echo "  --utun <number>    - Specify utun interface number (default: auto)"
    echo "  --foreground       - Run in foreground mode (don't detach)"
    echo ""
    echo "Examples:"
    echo "  ./utun-manager.sh start my-vpn"
    echo "  ./utun-manager.sh start my-vpn --utun 5"
    echo "  ./utun-manager.sh stop utun5"
    echo ""
    echo "Configuration files are stored in: $CONFIG_DIR"
    echo "Log files are stored in: $LOG_DIR"
}

# Check if WireGuard tools are installed
check_dependencies() {
    if ! command -v wg &> /dev/null; then
        echo -e "${RED}Error: WireGuard tools not found. Please install WireGuard tools.${NC}"
        echo "On macOS, you can install them with: brew install wireguard-tools"
        exit 1
    fi
    
    # Check for boringtun-cli
    if ! command -v "$BORINGTUN_BIN" &> /dev/null; then
        if [ -x "./target/release/boringtun-cli" ]; then
            BORINGTUN_BIN="./target/release/boringtun-cli"
        elif [ -x "./target/debug/boringtun-cli" ]; then
            BORINGTUN_BIN="./target/debug/boringtun-cli"
        else
            echo -e "${RED}Error: boringtun-cli not found. Please install it first:${NC}"
            echo "cargo install boringtun-cli"
            exit 1
        fi
    fi
}

# Function to start a WireGuard connection
start_connection() {
    local config_name="$1"
    local utun_num="$2"
    local foreground="$3"
    
    # Check if config exists
    local config_file="$CONFIG_DIR/$config_name.conf"
    if [ ! -f "$config_file" ]; then
        echo -e "${RED}Error: Configuration file '$config_file' not found${NC}"
        echo "Available configurations:"
        list_configs
        exit 1
    fi
    
    # Determine interface name
    local interface="utun"
    if [ -n "$utun_num" ]; then
        interface="utun$utun_num"
    fi
    
    # Create a temporary file to store the interface name
    local tun_name_file=$(mktemp)
    
    echo -e "${BLUE}Starting WireGuard connection using config: $config_name${NC}"
    
    # Run in foreground or background based on option
    if [ "$foreground" = "true" ]; then
        echo -e "${YELLOW}Running in foreground mode. Press Ctrl+C to stop.${NC}"
        sudo WG_TUN_NAME_FILE="$tun_name_file" \
             WG_QUICK_USERSPACE_IMPLEMENTATION="$BORINGTUN_BIN" \
             WG_SUDO=1 \
             wg-quick up "$config_file"
    else
        # Start in background
        echo -e "${YELLOW}Starting in background mode. Logs will be written to: $LOG_DIR/$config_name.log${NC}"
        
        # Start boringtun in background
        sudo WG_TUN_NAME_FILE="$tun_name_file" \
             "$BORINGTUN_BIN" "$interface" > "$LOG_DIR/$config_name.log" 2>&1 &
        
        # Store the PID
        local pid=$!
        echo $pid > "$CONFIG_DIR/$config_name.pid"
        
        # Wait briefly for the interface to be created
        sleep 1
        
        # Get the actual interface name
        if [ -f "$tun_name_file" ]; then
            interface=$(cat "$tun_name_file")
        fi
        
        # Configure WireGuard
        sudo wg setconf "$interface" <(wg-quick strip "$config_file")
        
        # Set up IP and routing based on the config
        local address=$(grep "^Address" "$config_file" | cut -d '=' -f 2 | tr -d ' ')
        if [ -n "$address" ]; then
            sudo ifconfig "$interface" inet "$address" up
        fi
        
        # Handle DNS if specified
        local dns=$(grep "^DNS" "$config_file" | cut -d '=' -f 2 | tr -d ' ')
        if [ -n "$dns" ]; then
            echo -e "${YELLOW}DNS settings found in config. You may need to update your DNS settings manually.${NC}"
            echo "DNS servers: $dns"
        fi
        
        echo -e "${GREEN}Connection started on interface $interface (PID: $pid)${NC}"
    fi
    
    # Clean up temp file
    rm -f "$tun_name_file"
}

# Function to stop a WireGuard connection
stop_connection() {
    local interface="$1"
    
    # If it's a config name rather than an interface
    if [[ ! "$interface" =~ ^utun[0-9]*$ ]]; then
        local config_name="$interface"
        local pid_file="$CONFIG_DIR/$config_name.pid"
        
        if [ -f "$pid_file" ]; then
            local pid=$(cat "$pid_file")
            echo -e "${BLUE}Stopping WireGuard connection for config: $config_name (PID: $pid)${NC}"
            sudo kill -TERM "$pid" 2>/dev/null || true
            rm -f "$pid_file"
            echo -e "${GREEN}Connection stopped${NC}"
        else
            echo -e "${RED}Error: No active connection found for config: $config_name${NC}"
            exit 1
        fi
    else
        # It's an interface name
        echo -e "${BLUE}Stopping WireGuard connection on interface: $interface${NC}"
        
        # Check if interface exists
        if ! ifconfig "$interface" &>/dev/null; then
            echo -e "${RED}Error: Interface $interface not found${NC}"
            exit 1
        fi
        
        # Find the process using this interface
        local pid=$(ps aux | grep "$BORINGTUN_BIN.*$interface" | grep -v grep | awk '{print $2}')
        
        if [ -n "$pid" ]; then
            sudo kill -TERM "$pid" 2>/dev/null || true
            echo -e "${GREEN}Connection on $interface stopped (PID: $pid)${NC}"
        else
            echo -e "${YELLOW}No boringtun process found for $interface, trying wg-quick...${NC}"
            sudo wg-quick down "$interface" 2>/dev/null || true
            echo -e "${GREEN}Connection on $interface stopped${NC}"
        fi
    fi
}

# Function to show status of all WireGuard interfaces
show_status() {
    echo -e "${BLUE}WireGuard Interface Status:${NC}"
    
    # Get all utun interfaces
    local interfaces=$(ifconfig | grep -o "utun[0-9]*" | sort -u)
    
    if [ -z "$interfaces" ]; then
        echo -e "${YELLOW}No active utun interfaces found${NC}"
        return
    fi
    
    # Check each interface
    for interface in $interfaces; do
        if sudo wg show "$interface" &>/dev/null; then
            echo -e "${GREEN}$interface: WireGuard active${NC}"
            sudo wg show "$interface"
            echo ""
        else
            echo -e "${YELLOW}$interface: Not a WireGuard interface${NC}"
        fi
    done
    
    # Show running boringtun processes
    echo -e "${BLUE}Running BoringTun Processes:${NC}"
    ps aux | grep "$BORINGTUN_BIN" | grep -v grep || echo -e "${YELLOW}No running BoringTun processes found${NC}"
}

# Function to list available configuration files
list_configs() {
    echo -e "${BLUE}Available WireGuard Configurations:${NC}"
    
    local configs=$(find "$CONFIG_DIR" -name "*.conf" -type f 2>/dev/null)
    
    if [ -z "$configs" ]; then
        echo -e "${YELLOW}No configuration files found in $CONFIG_DIR${NC}"
        return
    fi
    
    for config in $configs; do
        local name=$(basename "$config" .conf)
        local pid_file="$CONFIG_DIR/$name.pid"
        
        if [ -f "$pid_file" ] && kill -0 $(cat "$pid_file") 2>/dev/null; then
            echo -e "${GREEN}$name (ACTIVE)${NC}"
        else
            echo "$name"
        fi
    done
}

# Function to create a new configuration file template
create_config() {
    local name="$1"
    local config_file="$CONFIG_DIR/$name.conf"
    
    if [ -f "$config_file" ]; then
        echo -e "${RED}Error: Configuration file '$config_file' already exists${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}Creating new WireGuard configuration: $name${NC}"
    
    # Generate private key
    local private_key=$(wg genkey)
    local public_key=$(echo "$private_key" | wg pubkey)
    
    # Create config file
    cat > "$config_file" << EOF
# WireGuard configuration for $name
# Created on $(date)
# Public key: $public_key

[Interface]
PrivateKey = $private_key
Address = 10.0.0.2/24
# DNS = 1.1.1.1, 1.0.0.1

[Peer]
PublicKey = REPLACE_WITH_SERVER_PUBLIC_KEY
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = server.example.com:51820
PersistentKeepalive = 25
EOF

    echo -e "${GREEN}Configuration created at: $config_file${NC}"
    echo -e "${YELLOW}Important: Edit the file to set the correct server public key and endpoint!${NC}"
    echo "Your client public key is: $public_key"
}

# Parse command line arguments
COMMAND="$1"
shift || true

if [ -z "$COMMAND" ]; then
    show_help
    exit 0
fi

# Check dependencies
check_dependencies

# Process commands
case "$COMMAND" in
    start)
        CONFIG_NAME="$1"
        shift || true
        
        if [ -z "$CONFIG_NAME" ]; then
            echo -e "${RED}Error: No configuration name specified${NC}"
            show_help
            exit 1
        fi
        
        UTUN_NUM=""
        FOREGROUND="false"
        
        # Parse options
        while [ "$#" -gt 0 ]; do
            case "$1" in
                --utun)
                    UTUN_NUM="$2"
                    shift 2
                    ;;
                --foreground)
                    FOREGROUND="true"
                    shift
                    ;;
                *)
                    echo -e "${RED}Error: Unknown option: $1${NC}"
                    show_help
                    exit 1
                    ;;
            esac
        done
        
        start_connection "$CONFIG_NAME" "$UTUN_NUM" "$FOREGROUND"
        ;;
        
    stop)
        INTERFACE="$1"
        
        if [ -z "$INTERFACE" ]; then
            echo -e "${RED}Error: No interface or configuration name specified${NC}"
            show_help
            exit 1
        fi
        
        stop_connection "$INTERFACE"
        ;;
        
    status)
        show_status
        ;;
        
    list)
        list_configs
        ;;
        
    create)
        CONFIG_NAME="$1"
        
        if [ -z "$CONFIG_NAME" ]; then
            echo -e "${RED}Error: No configuration name specified${NC}"
            show_help
            exit 1
        fi
        
        create_config "$CONFIG_NAME"
        ;;
        
    help|--help|-h)
        show_help
        ;;
        
    *)
        echo -e "${RED}Unknown command: $COMMAND${NC}"
        show_help
        exit 1
        ;;
esac
