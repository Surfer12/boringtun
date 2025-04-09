#!/bin/bash
# boringtun-helper.sh - Helper script for building, running, and installing boringtun-cli
# Created: 2025-04-09

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to display usage information
show_help() {
    echo -e "${BLUE}BoringTun Helper Script${NC}"
    echo "Usage: ./boringtun-helper.sh [command]"
    echo ""
    echo "Commands:"
    echo "  build         - Build boringtun-cli in release mode"
    echo "  build-debug   - Build boringtun-cli in debug mode"
    echo "  build-lib     - Build only the boringtun library"
    echo "  install       - Install boringtun-cli using cargo"
    echo "  run [iface]   - Run boringtun-cli with the specified interface name"
    echo "                  (defaults to 'utun' on macOS if not specified)"
    echo "  wg-quick [config] - Run with wg-quick using the specified config file"
    echo "  status        - Show running boringtun-cli instances and interfaces"
    echo "  warp          - Show Cloudflare WARP status and commands"
    echo "  warp-connect  - Connect to Cloudflare WARP"
    echo "  warp-disconnect - Disconnect from Cloudflare WARP"
    echo "  warp-status   - Show Cloudflare WARP connection status"
    echo "  help          - Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./boringtun-helper.sh build"
    echo "  ./boringtun-helper.sh run utun5"
    echo "  ./boringtun-helper.sh wg-quick wg0-client"
    echo "  ./boringtun-helper.sh status"
    echo "  ./boringtun-helper.sh warp-connect"
}

# Function to build boringtun-cli in release mode
build_release() {
    echo -e "${BLUE}Building boringtun-cli in release mode...${NC}"
    cargo build --bin boringtun-cli --release
    echo -e "${GREEN}Build complete! Binary located at ./target/release/boringtun-cli${NC}"
}

# Function to build boringtun-cli in debug mode
build_debug() {
    echo -e "${BLUE}Building boringtun-cli in debug mode...${NC}"
    cargo build --bin boringtun-cli
    echo -e "${GREEN}Build complete! Binary located at ./target/debug/boringtun-cli${NC}"
}

# Function to build only the boringtun library
build_lib() {
    echo -e "${BLUE}Building boringtun library...${NC}"
    cargo build --lib --no-default-features --release
    echo -e "${GREEN}Library build complete!${NC}"
}

# Function to install boringtun-cli
install_boringtun() {
    echo -e "${BLUE}Installing boringtun-cli...${NC}"
    
    # Check if we're in a workspace and need to specify the package
    if grep -q "^\[workspace\]" Cargo.toml; then
        echo -e "${YELLOW}Detected workspace configuration, installing from crates.io...${NC}"
        cargo install boringtun-cli
    else
        # If not in a workspace, try to install from the local path
        cargo install --bin boringtun-cli --path .
    fi
    
    echo -e "${GREEN}Installation complete!${NC}"
}

# Function to run boringtun-cli
run_boringtun() {
    local interface=$1
    
    # Default to 'utun' on macOS if no interface specified
    if [ -z "$interface" ] && [ "$(uname)" == "Darwin" ]; then
        interface="utun"
        echo -e "${YELLOW}No interface specified, using default 'utun' for macOS${NC}"
    elif [ -z "$interface" ]; then
        echo -e "${RED}Error: Interface name required${NC}"
        show_help
        exit 1
    fi
    
    echo -e "${BLUE}Running boringtun-cli with interface: $interface${NC}"
    echo -e "${YELLOW}Note: This may require sudo privileges${NC}"
    
    if [ -x "./target/release/boringtun-cli" ]; then
        sudo ./target/release/boringtun-cli --foreground "$interface"
    elif [ -x "./target/debug/boringtun-cli" ]; then
        sudo ./target/debug/boringtun-cli --foreground "$interface"
    elif command -v boringtun-cli &> /dev/null; then
        sudo boringtun-cli --foreground "$interface"
    else
        echo -e "${RED}Error: boringtun-cli not found. Build it first with './boringtun-helper.sh build'${NC}"
        exit 1
    fi
}

# Function to run with wg-quick
run_wg_quick() {
    local config=$1
    
    if [ -z "$config" ]; then
        echo -e "${RED}Error: Configuration file required${NC}"
        show_help
        exit 1
    fi
    
    echo -e "${BLUE}Running with wg-quick using config: $config${NC}"
    echo -e "${YELLOW}Note: This requires sudo privileges${NC}"
    
    if [ -x "./target/release/boringtun-cli" ]; then
        sudo WG_QUICK_USERSPACE_IMPLEMENTATION=./target/release/boringtun-cli WG_SUDO=1 wg-quick up "$config"
    elif command -v boringtun-cli &> /dev/null; then
        sudo WG_QUICK_USERSPACE_IMPLEMENTATION=boringtun-cli WG_SUDO=1 wg-quick up "$config"
    else
        echo -e "${RED}Error: boringtun-cli not found. Build it first with './boringtun-helper.sh build'${NC}"
        exit 1
    fi
}

# Main script logic
case "$1" in
    build)
        build_release
        ;;
    build-debug)
        build_debug
        ;;
    build-lib)
        build_lib
        ;;
    install)
        install_boringtun
        ;;
    run)
        run_boringtun "$2"
        ;;
    wg-quick)
        run_wg_quick "$2"
        ;;
    status)
        show_status
        ;;
    warp)
        warp_commands
        ;;
    warp-connect)
        warp_connect
        ;;
    warp-disconnect)
        warp_disconnect
        ;;
    warp-status)
        warp_status
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        show_help
        exit 1
        ;;
esac
# Function to show status of running boringtun-cli instances
show_status() {
    echo -e "${BLUE}Checking for running boringtun-cli instances...${NC}"
    
    # Check for running processes
    echo -e "${YELLOW}Running processes:${NC}"
    if pgrep -f "boringtun-cli" > /dev/null; then
        ps aux | grep -v grep | grep "boringtun-cli"
    else
        echo -e "  ${RED}No boringtun-cli processes found${NC}"
    fi
    
    # On macOS, check for utun interfaces
    if [ "$(uname)" == "Darwin" ]; then
        echo -e "\n${YELLOW}Network interfaces:${NC}"
        ifconfig | grep -A1 "utun" | grep -v "^$"
    # On Linux, check for tun/wireguard interfaces
    elif [ "$(uname)" == "Linux" ]; then
        echo -e "\n${YELLOW}Network interfaces:${NC}"
        ip link show | grep -E "tun|wg"
    fi
    
    # Check WireGuard interfaces if wg command is available
    if command -v wg &> /dev/null; then
        echo -e "\n${YELLOW}WireGuard interfaces:${NC}"
        sudo wg show all 2>/dev/null || echo -e "  ${RED}No WireGuard interfaces found or permission denied${NC}"
    fi
}
# Function to handle Cloudflare WARP commands
warp_commands() {
    # Check if warp-cli is installed
    if ! command -v warp-cli &> /dev/null; then
        echo -e "${RED}Error: warp-cli not found. Please install Cloudflare WARP first.${NC}"
        echo -e "${YELLOW}Visit: https://developers.cloudflare.com/warp-client/get-started/linux/${NC}"
        exit 1
    fi

    echo -e "${BLUE}Cloudflare WARP CLI Commands${NC}"
    echo -e "${YELLOW}Available commands:${NC}"
    echo "  warp-cli register                - Register the WARP client"
    echo "  warp-cli connect                 - Connect to WARP"
    echo "  warp-cli disconnect              - Disconnect from WARP"
    echo "  warp-cli status                  - Show connection status"
    echo "  warp-cli enable-always-on        - Enable always-on mode"
    echo "  warp-cli disable-always-on       - Disable always-on mode"
    echo "  warp-cli warp-stats              - Show WARP connection statistics"
    echo "  warp-cli settings                - Show current settings"
    echo "  warp-cli account                 - Show account information"
    echo "  warp-cli teams-enroll [token]    - Enroll in Cloudflare for Teams"
    echo "  warp-cli teams-unenroll          - Unenroll from Cloudflare for Teams"
    echo ""
    echo -e "${YELLOW}Use this helper script for common operations:${NC}"
    echo "  ./boringtun-helper.sh warp-connect    - Connect to WARP"
    echo "  ./boringtun-helper.sh warp-disconnect - Disconnect from WARP"
    echo "  ./boringtun-helper.sh warp-status     - Show connection status"
}

# Function to connect to Cloudflare WARP
warp_connect() {
    echo -e "${BLUE}Connecting to Cloudflare WARP...${NC}"
    
    # Check if warp-cli is installed
    if ! command -v warp-cli &> /dev/null; then
        echo -e "${RED}Error: warp-cli not found. Please install Cloudflare WARP first.${NC}"
        exit 1
    fi
    
    # Connect to WARP
    warp-cli connect
    
    # Check status after connecting
    sleep 2
    warp-cli status
}

# Function to disconnect from Cloudflare WARP
warp_disconnect() {
    echo -e "${BLUE}Disconnecting from Cloudflare WARP...${NC}"
    
    # Check if warp-cli is installed
    if ! command -v warp-cli &> /dev/null; then
        echo -e "${RED}Error: warp-cli not found. Please install Cloudflare WARP first.${NC}"
        exit 1
    fi
    
    # Disconnect from WARP
    warp-cli disconnect
    
    # Check status after disconnecting
    sleep 2
    warp-cli status
}

# Function to show Cloudflare WARP status
warp_status() {
    echo -e "${BLUE}Checking Cloudflare WARP status...${NC}"
    
    # Check if warp-cli is installed
    if ! command -v warp-cli &> /dev/null; then
        echo -e "${RED}Error: warp-cli not found. Please install Cloudflare WARP first.${NC}"
        exit 1
    fi
    
    # Show WARP status
    echo -e "${YELLOW}Connection status:${NC}"
    warp-cli status
    
    echo -e "\n${YELLOW}WARP statistics:${NC}"
    warp-cli warp-stats
    
    echo -e "\n${YELLOW}Current settings:${NC}"
    warp-cli settings
    
    # Check if account info is available
    if warp-cli account 2>/dev/null | grep -q "Account type"; then
        echo -e "\n${YELLOW}Account information:${NC}"
        warp-cli account
    fi
}

# Show success message
echo -e "${GREEN}BoringTun helper script executed successfully!${NC}"
