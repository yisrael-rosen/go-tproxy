const std = @import("std");
const tcp = @import("tcp.zig");
const udp = @import("udp.zig");

pub const TCP = tcp;
pub const UDP = udp;

pub const TcpListener = tcp.Listener;
pub const TcpConn = tcp.Conn;
pub const UdpConn = udp.Conn;

test {
    std.testing.refAllDecls(@This());
}
