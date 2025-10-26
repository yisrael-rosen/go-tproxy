Zig TProxy
=============

[![CI](https://github.com/yisrael-rosen/go-tproxy/workflows/CI/badge.svg)](https://github.com/yisrael-rosen/go-tproxy/actions/workflows/ci.yml)
[![Docker Build](https://github.com/yisrael-rosen/go-tproxy/workflows/Docker%20Build/badge.svg)](https://github.com/yisrael-rosen/go-tproxy/actions/workflows/docker.yml)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENCE.md)

Zig TProxy provides an easy to use wrapper for the [Linux Transparent Proxy][1] functionality.

> **Note:** This project has been migrated from Go to Zig. For the original Go implementation, see the [Go branch](https://github.com/LiamHaworth/go-tproxy/tree/go-version).

Transparent Proxy (TProxy for short) provides the ability to transparently proxy traffic through a userland
program without the need for conntrack overhead caused by using NAT to force the traffic into the proxy.

Another feature of TProxy is the ability to connect to remote hosts using the same client information as
the original client making the connection. For example, if the connection `10.0.0.1:50073 -> 8.8.8.8:80` was
intercepted, the service could make a connection to `8.8.8.8:80` pretending to come from `10.0.0.1:50073`.

The linux kernel and IPTables handle diverting the packets back into the proxy for those remote connections by
matching incoming packets to any locally bound sockets with the same details.

This is done in three steps. (Please note, this is from my understanding of how it works, which may be wrong in some places,
so please correct me if I have described something wrong)

#### Step 1 - Binding a listener socket with the `IP_TRANSPARENT` socket option

Preparing a socket to receive connections with TProxy is really no different than what is normally done when
setting up a socket to listen for connections. The only difference in the process is before the socket is bound,
the `IP_TRANSPARENT` socket option.

```zig
try os.setsockopt(
    sockfd,
    SOL_IP,
    IP_TRANSPARENT,
    &std.mem.toBytes(@as(c_int, 1)),
);
```

#### Step 2 - Setting the `IP_TRANSPARENT` socket option on outbound connections

Same goes for making connections to a remote host pretending to be the client, the `IP_TRANSPARENT` socket
option is set and the Linux kernel will allow the bind so along as a connection was intercepted with those details
being used for the bind

#### Step 3 - Adding IPTables and routing rules to redirect traffic in both directions

Finally IPTables and routing rules need to be setup to tell Linux to redirect the desired traffic to the proxy
application.

First make a new chain in the mangle table called `DIVERT` and add a rule to direct any TCP traffic with a matching
local socket to the `DIVERT` chain
```sh
iptables -t mangle -N DIVERT
iptables -t mangle -A PREROUTING -p tcp -m socket -j DIVERT
```

Then in the `DIVERT` chain add rules to add routing mark of `1` to packets in the `DIVERT` chain and accept the packets
```sh
iptables -t mangle -A DIVERT -j MARK --set-mark 1
iptables -t mangle -A DIVERT -j ACCEPT
```

And add routing rules to direct traffic with mark `1` to the local loopback device so the Linux kernal can pipe the
traffic into the existing socket.
```sh
ip rule add fwmark 1 lookup 100
ip route add local 0.0.0.0/0 dev lo table 100
```

Finally add a IPTables rule to catch new traffic on any desired port and send it to the TProxy server
```sh
iptables -t mangle -A PREROUTING -p tcp --dport 80 -j TPROXY --tproxy-mark 0x1/0x1 --on-port 8080
```

## Building and Running

**Requirements:**
- Zig 0.13.0 or later (recommended: 0.13.0 or 0.15.x)
- Linux operating system (for TPROXY kernel feature)
- Root privileges (for IP_TRANSPARENT socket option)

> **Note**: This code uses `std.posix` which was introduced in Zig 0.12. For older Zig versions (0.11 and earlier), you would need to replace `std.posix` with `std.os`.

### Quick Start

The easiest way to get started is using the included test script:

```sh
# This will download Zig locally if not installed and build the project
./test-build.sh
```

### Manual Build

```sh
# Build the library and example
zig build

# Run the example (requires root)
sudo zig build run
```

The example application will bind to `0.0.0.0:8080` for both TCP and UDP traffic.

### Usage in Your Project

To use this library in your Zig project, add it as a dependency in your `build.zig`:

```zig
const tproxy = @import("tproxy");

// Create a TCP listener
var tcp_listener = try tproxy.TCP.Listener.listen(bind_addr);
defer tcp_listener.close();

// Accept connections
var conn = try tcp_listener.accept();
defer conn.close();

// Dial original destination
const remote_fd = try conn.dialOriginalDestination(false);
defer os.closeSocket(remote_fd);
```

### Testing

To test this out and see it work, try running the example on a virtual machine and route some traffic through it using the iptables rules described above.

Contributing
=============

To contribute to this project, please follow this guide:

  1. Create an issue detailing your planned contribution
  2. Fork this repository and implement your contribution
  3. Create a pull request linking back to the issue
  4. Await approval and merging
  
TODOs
=====

 [x] ~~Add support for proxying UDP connections~~




[1]: https://www.kernel.org/doc/Documentation/networking/tproxy.txt