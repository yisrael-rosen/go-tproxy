# Dockerfile for building and testing the Zig TProxy library
FROM alpine:latest

# Install dependencies
RUN apk add --no-cache \
    curl \
    tar \
    xz \
    iptables \
    iproute2

# Install Zig 0.13.0
RUN curl -L https://ziglang.org/download/0.13.0/zig-linux-x86_64-0.13.0.tar.xz -o /tmp/zig.tar.xz && \
    tar -xf /tmp/zig.tar.xz -C /opt && \
    ln -s /opt/zig-linux-x86_64-0.13.0/zig /usr/local/bin/zig && \
    rm /tmp/zig.tar.xz

# Set working directory
WORKDIR /app

# Copy project files
COPY . .

# Build the project
RUN zig build

# Default command
CMD ["zig", "build", "run"]
