const std = @import("std");
const os = std.posix;
const net = std.net;

// Socket options constants
const IP_TRANSPARENT = 19;
const SOL_IP = 0;

/// Listener represents a TCP listener with the Linux IP_TRANSPARENT
/// option set on the listening socket.
pub const Listener = struct {
    sockfd: os.socket_t,
    address: net.Address,

    /// Listen creates a new TCP listener with IP_TRANSPARENT socket option
    pub fn listen(address: net.Address) !Listener {
        const sockfd = try os.socket(
            address.any.family,
            os.SOCK.STREAM | os.SOCK.CLOEXEC,
            os.IPPROTO.TCP,
        );
        errdefer os.closeSocket(sockfd);

        // Set SO_REUSEADDR
        try os.setsockopt(
            sockfd,
            os.SOL.SOCKET,
            os.SO.REUSEADDR,
            &std.mem.toBytes(@as(c_int, 1)),
        );

        // Set IP_TRANSPARENT
        try os.setsockopt(
            sockfd,
            SOL_IP,
            IP_TRANSPARENT,
            &std.mem.toBytes(@as(c_int, 1)),
        );

        // Bind the socket
        try os.bind(sockfd, &address.any, address.getOsSockLen());

        // Listen for connections
        try os.listen(sockfd, 128);

        return Listener{
            .sockfd = sockfd,
            .address = address,
        };
    }

    /// Accept waits for and returns the next connection to the listener
    pub fn accept(self: *Listener) !Conn {
        var client_addr: net.Address = undefined;
        var client_addr_len: os.socklen_t = @sizeOf(net.Address);

        const client_fd = try os.accept(
            self.sockfd,
            &client_addr.any,
            &client_addr_len,
            os.SOCK.CLOEXEC,
        );

        return Conn{
            .sockfd = client_fd,
            .local_address = client_addr,
        };
    }

    /// Close closes the listener
    pub fn close(self: *Listener) void {
        os.closeSocket(self.sockfd);
    }
};

/// Conn represents a TCP connection accepted by a TProxy listener.
/// It provides the ability to dial the original destination while
/// assuming the IP address of the client.
pub const Conn = struct {
    sockfd: os.socket_t,
    local_address: net.Address,

    /// Get the remote (original destination) address
    pub fn getRemoteAddress(self: Conn) !net.Address {
        var addr: net.Address = undefined;
        var addr_len: os.socklen_t = @sizeOf(net.Address);
        try os.getsockname(self.sockfd, &addr.any, &addr_len);
        return addr;
    }

    /// Get the local (client) address
    pub fn getLocalAddress(self: Conn) net.Address {
        return self.local_address;
    }

    /// Dial the original destination, optionally spoofing the client's address
    pub fn dialOriginalDestination(self: Conn, dont_assume_remote: bool) !os.socket_t {
        const remote_addr = try self.getRemoteAddress();
        const local_addr = self.local_address;

        // Create socket
        const sockfd = try os.socket(
            remote_addr.any.family,
            os.SOCK.STREAM | os.SOCK.NONBLOCK | os.SOCK.CLOEXEC,
            os.IPPROTO.TCP,
        );
        errdefer os.closeSocket(sockfd);

        // Set SO_REUSEADDR
        try os.setsockopt(
            sockfd,
            os.SOL.SOCKET,
            os.SO.REUSEADDR,
            &std.mem.toBytes(@as(c_int, 1)),
        );

        // Set IP_TRANSPARENT
        try os.setsockopt(
            sockfd,
            SOL_IP,
            IP_TRANSPARENT,
            &std.mem.toBytes(@as(c_int, 1)),
        );

        // Bind to client's address if not assuming remote
        if (!dont_assume_remote) {
            try os.bind(sockfd, &local_addr.any, local_addr.getOsSockLen());
        }

        // Connect to the original destination
        os.connect(sockfd, &remote_addr.any, remote_addr.getOsSockLen()) catch |err| {
            // EINPROGRESS is expected for non-blocking sockets
            if (err != error.WouldBlock) {
                return err;
            }
        };

        return sockfd;
    }

    /// Read data from the connection
    pub fn read(self: Conn, buffer: []u8) !usize {
        return os.read(self.sockfd, buffer);
    }

    /// Write data to the connection
    pub fn write(self: Conn, data: []const u8) !usize {
        return os.write(self.sockfd, data);
    }

    /// Close the connection
    pub fn close(self: *Conn) void {
        os.closeSocket(self.sockfd);
    }
};
