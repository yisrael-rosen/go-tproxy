# Contributing to Zig TProxy

Thank you for your interest in contributing to Zig TProxy! This document provides guidelines and instructions for contributing.

## Code of Conduct

Be respectful and constructive in all interactions. We're here to build great software together.

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally
   ```bash
   git clone https://github.com/YOUR_USERNAME/go-tproxy.git
   cd go-tproxy
   ```
3. **Set up your development environment**
   ```bash
   # Install Zig (see INSTALL.md for detailed instructions)
   ./test-build.sh
   ```

## Development Workflow

### Making Changes

1. **Create a new branch** for your feature/fix
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**
   - Follow Zig coding conventions
   - Keep changes focused and atomic
   - Write clear commit messages

3. **Format your code**
   ```bash
   zig fmt src/ example/
   ```

4. **Build and test**
   ```bash
   zig build
   # Test your changes
   ```

5. **Commit your changes**
   ```bash
   git add .
   git commit -m "feat: add your feature description"
   ```

   Use conventional commit format:
   - `feat:` - New features
   - `fix:` - Bug fixes
   - `docs:` - Documentation changes
   - `refactor:` - Code refactoring
   - `test:` - Test additions/changes
   - `ci:` - CI/CD changes

### Submitting a Pull Request

1. **Push to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```

2. **Open a Pull Request** on GitHub
   - Use the PR template
   - Provide a clear description
   - Reference any related issues
   - Ensure CI checks pass

3. **Respond to feedback**
   - Address review comments
   - Update your PR as needed
   - Be patient and collaborative

## Code Style

- **Formatting**: Use `zig fmt` for all Zig code
- **Naming**:
  - `camelCase` for functions and variables
  - `PascalCase` for types and structs
  - `SCREAMING_SNAKE_CASE` for constants
- **Comments**: Document public APIs and complex logic
- **Error Handling**: Use Zig's error handling (`try`, `catch`, `errdefer`)

## Testing

Currently, the project builds a library and example application. When contributing:

1. Ensure `zig build` completes without errors
2. Test on a Linux system with TPROXY support
3. Verify iptables integration works
4. Test both TCP and UDP transparent proxying

## Documentation

When adding features or making changes:

1. Update `README.md` if user-facing functionality changes
2. Update `INSTALL.md` if installation process changes
3. Add/update code comments for complex logic
4. Update examples if API changes

## Project Structure

```
go-tproxy/
├── src/
│   ├── tproxy.zig      # Main module
│   ├── tcp.zig         # TCP implementation
│   └── udp.zig         # UDP implementation
├── example/
│   └── tproxy_example.zig
├── .github/
│   ├── workflows/      # CI/CD workflows
│   └── ISSUE_TEMPLATE/ # Issue templates
├── build.zig           # Build configuration
├── Dockerfile          # Docker build
└── README.md           # Documentation
```

## Requirements

- **Platform**: Linux only (uses Linux-specific TPROXY features)
- **Zig Version**: 0.13.0 or later
- **Permissions**: Root/CAP_NET_ADMIN for testing

## Questions?

- Open an issue for bugs or feature requests
- Check existing issues and PRs first
- Be specific and provide examples

## License

By contributing, you agree that your contributions will be licensed under the same license as the project (see LICENCE.md).

Thank you for contributing! 🎉
