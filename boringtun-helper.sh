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
    echo "  help          - Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./boringtun-helper.sh build"
    echo "  ./boringtun-helper.sh run utun5"
    echo "  ./boringtun-helper.sh wg-quick wg0-client"
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
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        show_help
        exit 1
        ;;
esac
