const std = @import("std");
const tproxy = @import("../src/tproxy.zig");
const net = std.net;
const os = std.posix;

const log = std.log;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    log.info("Starting Zig TProxy example", .{});

    // Parse address for binding
    const bind_addr = try net.Address.parseIp4("0.0.0.0", 8080);

    // Create TCP listener
    log.info("Binding TCP TProxy listener to 0.0.0.0:8080", .{});
    var tcp_listener = try tproxy.TCP.Listener.listen(bind_addr);
    defer tcp_listener.close();

    // Create UDP listener
    log.info("Binding UDP TProxy listener to 0.0.0.0:8080", .{});
    var udp_listener = try tproxy.UDP.Conn.listen(bind_addr);
    defer udp_listener.close();

    // Spawn threads for handling connections
    const tcp_thread = try std.Thread.spawn(.{}, listenTcp, .{&tcp_listener});
    const udp_thread = try std.Thread.spawn(.{}, listenUdp, .{ &udp_listener, allocator });

    log.info("TProxy listeners running. Press Ctrl+C to stop.", .{});

    // Wait for threads (they run forever)
    tcp_thread.join();
    udp_thread.join();
}

fn listenTcp(listener: *tproxy.TCP.Listener) void {
    while (true) {
        var conn = listener.accept() catch |err| {
            log.err("Failed to accept TCP connection: {}", .{err});
            continue;
        };

        // Spawn a thread to handle the connection
        const thread = std.Thread.spawn(.{}, handleTcpConn, .{conn}) catch |err| {
            log.err("Failed to spawn TCP handler thread: {}", .{err});
            conn.close();
            continue;
        };
        thread.detach();
    }
}

fn handleTcpConn(conn: tproxy.TCP.Conn) void {
    defer conn.close();

    const remote_addr = conn.getRemoteAddress() catch |err| {
        log.err("Failed to get remote address: {}", .{err});
        return;
    };

    const local_addr = conn.getLocalAddress();
    log.info("Accepting TCP connection from {} with destination of {}", .{ local_addr, remote_addr });

    // Dial the original destination
    const remote_fd = conn.dialOriginalDestination(false) catch |err| {
        log.err("Failed to connect to original destination [{}]: {}", .{ remote_addr, err });
        return;
    };
    defer os.closeSocket(remote_fd);

    // Create a simple proxy by copying data between connections
    var buffer: [4096]u8 = undefined;

    // This is a simplified version - a real implementation would use
    // non-blocking I/O and poll/epoll for bidirectional forwarding
    while (true) {
        const n = conn.read(&buffer) catch |err| {
            if (err != error.EndOfStream) {
                log.err("Failed to read from client: {}", .{err});
            }
            break;
        };

        if (n == 0) break;

        _ = os.write(remote_fd, buffer[0..n]) catch |err| {
            log.err("Failed to write to remote: {}", .{err});
            break;
        };
    }
}

fn listenUdp(listener: *tproxy.UDP.Conn, allocator: std.mem.Allocator) void {
    var buffer: [4096]u8 = undefined;
    var control_buffer: [1024]u8 = undefined;

    while (true) {
        const packet = listener.readFrom(&buffer, &control_buffer) catch |err| {
            log.err("Failed to read UDP packet: {}", .{err});
            continue;
        };

        log.info("Accepting UDP connection from {} with destination of {}", .{
            packet.src_addr,
            packet.dst_addr,
        });

        // Spawn a thread to handle the packet
        const data_copy = allocator.dupe(u8, packet.data[0..packet.len]) catch |err| {
            log.err("Failed to allocate memory for UDP packet: {}", .{err});
            continue;
        };

        const context = allocator.create(UdpContext) catch |err| {
            log.err("Failed to allocate UDP context: {}", .{err});
            allocator.free(data_copy);
            continue;
        };

        context.* = .{
            .data = data_copy,
            .src_addr = packet.src_addr,
            .dst_addr = packet.dst_addr,
            .allocator = allocator,
        };

        const thread = std.Thread.spawn(.{}, handleUdpPacket, .{context}) catch |err| {
            log.err("Failed to spawn UDP handler thread: {}", .{err});
            allocator.free(data_copy);
            allocator.destroy(context);
            continue;
        };
        thread.detach();
    }
}

const UdpContext = struct {
    data: []u8,
    src_addr: net.Address,
    dst_addr: net.Address,
    allocator: std.mem.Allocator,
};

fn handleUdpPacket(context: *UdpContext) void {
    defer context.allocator.free(context.data);
    defer context.allocator.destroy(context);

    log.info("Handling UDP packet from {} to {}", .{ context.src_addr, context.dst_addr });

    // Connect to the original destination, spoofing the source address
    var remote_conn = tproxy.UDP.Conn.dial(context.src_addr, context.dst_addr) catch |err| {
        log.err("Failed to connect to original UDP destination [{}]: {}", .{ context.dst_addr, err });
        return;
    };
    defer remote_conn.close();

    // Send the data to the remote host
    _ = remote_conn.write(context.data) catch |err| {
        log.err("Failed to write to remote: {}", .{err});
        return;
    };

    // Wait for a response with a timeout
    var response_buffer: [4096]u8 = undefined;
    remote_conn.setReadTimeout(2000) catch |err| {
        log.err("Failed to set timeout: {}", .{err});
        return;
    };

    const n = remote_conn.read(&response_buffer) catch |err| {
        // Timeout is expected if there's no response
        if (err == error.WouldBlock) return;
        log.err("Failed to read from remote: {}", .{err});
        return;
    };

    // Send response back to the client
    var local_conn = tproxy.UDP.Conn.dial(context.dst_addr, context.src_addr) catch |err| {
        log.err("Failed to connect back to client [{}]: {}", .{ context.src_addr, err });
        return;
    };
    defer local_conn.close();

    _ = local_conn.write(response_buffer[0..n]) catch |err| {
        log.err("Failed to write response to client: {}", .{err});
        return;
    };
}
