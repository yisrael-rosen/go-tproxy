# Installation Guide

This guide provides multiple methods for installing Zig and building the tproxy project.

## Prerequisites

- Linux operating system (required for TPROXY functionality)
- Root/sudo access (for setting IP_TRANSPARENT socket options)

## Method 1: Using Pre-built Binaries (Recommended)

### Download Zig

```bash
# Download Zig 0.13.0
cd /opt
sudo wget https://ziglang.org/download/0.13.0/zig-linux-x86_64-0.13.0.tar.xz

# Extract
sudo tar -xf zig-linux-x86_64-0.13.0.tar.xz

# Create symlink
sudo ln -s /opt/zig-linux-x86_64-0.13.0/zig /usr/local/bin/zig

# Verify installation
zig version
# Should output: 0.13.0
```

### Build the Project

```bash
cd /path/to/go-tproxy
zig build
```

### Run the Example

```bash
# Requires root for IP_TRANSPARENT
sudo zig build run
```

## Method 2: Using Docker

```bash
# Build the Docker image
docker build -t zig-tproxy .

# Run the example
docker run --rm --cap-add=NET_ADMIN zig-tproxy
```

## Method 3: Using Package Managers

### Snap (if available)

```bash
sudo snap install zig --classic --beta
```

### From Source (Advanced)

```bash
# Install dependencies
sudo apt update
sudo apt install -y cmake clang llvm-dev libclang-dev lld

# Clone Zig
git clone https://github.com/ziglang/zig.git
cd zig
git checkout 0.13.0

# Build (this takes a while)
mkdir build
cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make install
```

## Troubleshooting

### Network Restrictions

If you cannot download from ziglang.org directly, try these alternatives:

1. **GitHub Releases**: https://github.com/ziglang/zig/releases/tag/0.13.0
2. **Mirrors**: Check https://ziglang.org/download/ for alternative mirrors
3. **Use Docker**: The Dockerfile in this repo handles the download

### Permission Errors

The TProxy functionality requires CAP_NET_ADMIN capability. Run with sudo or grant the capability:

```bash
# Option 1: Run with sudo
sudo zig build run

# Option 2: Grant capability (after building)
sudo setcap cap_net_admin=eip ./zig-out/bin/tproxy_example
./zig-out/bin/tproxy_example
```

### Build Errors

If you encounter build errors, ensure you're using Zig 0.13.0 or later:

```bash
zig version
# Should output: 0.13.0
```

## Setting Up IPTables Rules

After building, you need to configure iptables for transparent proxying:

```bash
# Create DIVERT chain
sudo iptables -t mangle -N DIVERT
sudo iptables -t mangle -A PREROUTING -p tcp -m socket -j DIVERT

# Mark and accept diverted packets
sudo iptables -t mangle -A DIVERT -j MARK --set-mark 1
sudo iptables -t mangle -A DIVERT -j ACCEPT

# Add routing rules
sudo ip rule add fwmark 1 lookup 100
sudo ip route add local 0.0.0.0/0 dev lo table 100

# Redirect traffic to TProxy (port 8080)
sudo iptables -t mangle -A PREROUTING -p tcp --dport 80 -j TPROXY --tproxy-mark 0x1/0x1 --on-port 8080
sudo iptables -t mangle -A PREROUTING -p udp --dport 80 -j TPROXY --tproxy-mark 0x1/0x1 --on-port 8080
```

## Next Steps

Once installed, refer to the main README.md for usage examples and API documentation.
