# Manual Zig Installation Guide

Since automated downloads are blocked in this environment, here's how to manually install Zig:

## Download the File Externally

1. On a machine with unrestricted internet access, download:
   ```
   https://ziglang.org/builds/zig-x86_64-linux-0.16.0-dev.747+493ad58ff.tar.xz
   ```

2. Transfer the file to this project directory using one of these methods:
   - SCP/SFTP
   - Mount a volume
   - Copy via shared filesystem
   - Use `docker cp` if in a container

## Install Locally

Once you have the file in `/home/user/go-tproxy/`, run:

```bash
# Extract Zig
tar -xf zig-x86_64-linux-0.16.0-dev.747+493ad58ff.tar.xz

# Add to PATH temporarily
export PATH="${PWD}/zig-x86_64-linux-0.16.0-dev.747+493ad58ff:${PATH}"

# Verify installation
zig version

# Build the project
zig build
```

## Alternative: System-wide Installation

```bash
# Extract to /opt
sudo tar -xf zig-x86_64-linux-0.16.0-dev.747+493ad58ff.tar.xz -C /opt/

# Create symlink
sudo ln -s /opt/zig-x86_64-linux-0.16.0-dev.747+493ad58ff/zig /usr/local/bin/zig

# Verify
zig version
```

## Quick Test After Installation

```bash
# Build the project
zig build

# Test (requires root for TPROXY)
sudo zig build run
```

## Network Restriction Details

Current environment has a proxy that blocks ziglang.org:
- Proxy: `21.0.0.55:15002`
- Error: `403 Forbidden`
- Affected URLs: `https://ziglang.org/*`

If you have proxy bypass capabilities, you could try:
```bash
export no_proxy="$no_proxy,ziglang.org,*.ziglang.org"
# Then retry download
```
