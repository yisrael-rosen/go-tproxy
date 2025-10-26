const std = @import("std");
const os = std.posix;
const net = std.net;

// Socket options constants
const IP_TRANSPARENT = 19;
const IP_RECVORIGDSTADDR = 20;
const SOL_IP = 0;

/// UDP packet information
pub const UdpPacket = struct {
    data: []u8,
    len: usize,
    src_addr: net.Address,
    dst_addr: net.Address,
};

/// Conn represents a UDP connection with TProxy support
pub const Conn = struct {
    sockfd: os.socket_t,
    address: net.Address,

    /// Listen creates a new UDP socket with IP_TRANSPARENT and IP_RECVORIGDSTADDR options
    pub fn listen(address: net.Address) !Conn {
        const sockfd = try os.socket(
            address.any.family,
            os.SOCK.DGRAM | os.SOCK.CLOEXEC,
            os.IPPROTO.UDP,
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

        // Set IP_RECVORIGDSTADDR
        try os.setsockopt(
            sockfd,
            SOL_IP,
            IP_RECVORIGDSTADDR,
            &std.mem.toBytes(@as(c_int, 1)),
        );

        // Bind the socket
        try os.bind(sockfd, &address.any, address.getOsSockLen());

        return Conn{
            .sockfd = sockfd,
            .address = address,
        };
    }

    /// Read a UDP packet with original destination information
    pub fn readFrom(self: Conn, buffer: []u8, control_buffer: []u8) !UdpPacket {
        var src_addr: net.Address = undefined;
        var iov = [_]os.iovec_const{
            .{
                .base = buffer.ptr,
                .len = buffer.len,
            },
        };

        var msg = os.msghdr_const{
            .name = @ptrCast(&src_addr.any),
            .namelen = @sizeOf(net.Address),
            .iov = &iov,
            .iovlen = 1,
            .control = control_buffer.ptr,
            .controllen = control_buffer.len,
            .flags = 0,
        };

        const n = try os.recvmsg(self.sockfd, @ptrCast(&msg), 0);

        // Parse control messages to get original destination
        var dst_addr: ?net.Address = null;
        var cmsg_iter = ControlMessageIterator.init(@as([*]u8, @ptrCast(msg.control))[0..msg.controllen]);

        while (cmsg_iter.next()) |cmsg| {
            if (cmsg.level == SOL_IP and cmsg.type == IP_RECVORIGDSTADDR) {
                // Parse the sockaddr from control message data
                const sockaddr_ptr: *align(1) const os.sockaddr = @ptrCast(cmsg.data.ptr);
                if (sockaddr_ptr.family == os.AF.INET) {
                    const addr4: *align(1) const os.sockaddr.in = @ptrCast(sockaddr_ptr);
                    dst_addr = net.Address.initIp4(
                        @as([4]u8, @bitCast(addr4.addr)),
                        @byteSwap(addr4.port),
                    );
                } else if (sockaddr_ptr.family == os.AF.INET6) {
                    const addr6: *align(1) const os.sockaddr.in6 = @ptrCast(sockaddr_ptr);
                    dst_addr = net.Address.initIp6(
                        addr6.addr,
                        @byteSwap(addr6.port),
                        addr6.flowinfo,
                        addr6.scope_id,
                    );
                }
            }
        }

        return UdpPacket{
            .data = buffer,
            .len = n,
            .src_addr = src_addr,
            .dst_addr = dst_addr orelse return error.OriginalDestinationNotFound,
        };
    }

    /// Dial creates a UDP connection to a remote address, optionally with a local address
    pub fn dial(local_addr: net.Address, remote_addr: net.Address) !Conn {
        const sockfd = try os.socket(
            remote_addr.any.family,
            os.SOCK.DGRAM | os.SOCK.CLOEXEC,
            os.IPPROTO.UDP,
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

        // Bind to local address
        try os.bind(sockfd, &local_addr.any, local_addr.getOsSockLen());

        // Connect to remote address
        try os.connect(sockfd, &remote_addr.any, remote_addr.getOsSockLen());

        return Conn{
            .sockfd = sockfd,
            .address = remote_addr,
        };
    }

    /// Write data to the connection
    pub fn write(self: Conn, data: []const u8) !usize {
        return os.write(self.sockfd, data);
    }

    /// Read data from the connection
    pub fn read(self: Conn, buffer: []u8) !usize {
        return os.read(self.sockfd, buffer);
    }

    /// Set read timeout
    pub fn setReadTimeout(self: Conn, timeout_ms: u64) !void {
        const timeout = os.timeval{
            .sec = @intCast(@divFloor(timeout_ms, 1000)),
            .usec = @intCast(@mod(timeout_ms, 1000) * 1000),
        };
        try os.setsockopt(
            self.sockfd,
            os.SOL.SOCKET,
            os.SO.RCVTIMEO,
            std.mem.asBytes(&timeout),
        );
    }

    /// Close the connection
    pub fn close(self: *Conn) void {
        os.closeSocket(self.sockfd);
    }
};

/// Control message iterator for parsing ancillary data
const ControlMessageIterator = struct {
    data: []const u8,
    offset: usize,

    const ControlMessage = struct {
        level: c_int,
        type: c_int,
        data: []const u8,
    };

    fn init(data: []const u8) ControlMessageIterator {
        return .{ .data = data, .offset = 0 };
    }

    fn next(self: *ControlMessageIterator) ?ControlMessage {
        if (self.offset >= self.data.len) return null;

        const cmsg_ptr: *align(1) const os.cmsghdr = @ptrCast(self.data[self.offset..].ptr);
        const cmsg_len = cmsg_ptr.len;

        if (cmsg_len < @sizeOf(os.cmsghdr) or self.offset + cmsg_len > self.data.len) {
            return null;
        }

        const data_start = self.offset + @sizeOf(os.cmsghdr);
        const data_len = cmsg_len - @sizeOf(os.cmsghdr);
        const msg_data = self.data[data_start..][0..data_len];

        const result = ControlMessage{
            .level = cmsg_ptr.level,
            .type = cmsg_ptr.type,
            .data = msg_data,
        };

        // Move to next control message (aligned to pointer size)
        self.offset += std.mem.alignForward(usize, cmsg_len, @alignOf(usize));

        return result;
    }
};
