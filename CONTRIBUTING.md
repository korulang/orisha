# Contributing to Orisha

Thank you for your interest in contributing! 🌍

## Getting Started

1. **Fork the repository**
2. **Clone your fork**: `git clone https://github.com/YOUR_USERNAME/orisha.git`
3. **Create a branch**: `git checkout -b feature/your-feature-name`

## Development Setup

### Prerequisites

- [Koru compiler](https://github.com/koru-lang/koru) installed and in PATH
- Zig 0.13+ (for build dependencies)
- Node.js 20+ (optional, for npm integration)

### Building

```bash
cd ~/src/orisha
koruc --check examples/hello/main.kz  # Check syntax
```

### Running Tests

*Test infrastructure coming soon*

## Project Structure

Each Orisha component lives in its own directory:

```
eshu/           # HTTP routing (in development)
oya/            # Templates (in development)
oshun/          # Database (planned)
shango/         # Auth (planned)
ogun/           # Build tools (planned)
yemoja/         # State management (planned)
```

## Coding Guidelines

### Koru Style

- Follow Koru's naming conventions
- Use phantom types for resource obligations
- Leverage compile-time evaluation where possible
- Document complex continuation flows

### Comments

- Explain **why**, not **what**
- Document phantom type obligations
- Note performance considerations
- Reference relevant tests

### Testing

- Add regression tests for bug fixes
- Create examples for new features
- Test both success and error paths
- Verify obligation tracking

## What to Contribute

### High Priority

- **Eshu**: HTTP server implementation
- **Oya**: Template parser and renderer
- **Examples**: Real-world usage demonstrations
- **Documentation**: API docs, guides, tutorials

### Future Work

- Oshun (database/ORM)
- Shango (authentication)
- Ogun (build tools)
- Yemoja (state management)

## Commit Messages

Use clear, descriptive commit messages:

```
[component] Brief description

Detailed explanation of what changed and why.

Fixes #123
```

Examples:
- `[eshu] Add route collector pass`
- `[oya] Implement template interpolation`
- `[docs] Add HTTP routing guide`

## Pull Request Process

1. **Update documentation** if you've changed APIs
2. **Add tests** for new functionality
3. **Ensure it builds**: `koruc --check` should pass
4. **Write a clear PR description** explaining the changes
5. **Reference issues** if applicable

## Questions?

- Open an issue for bugs or feature requests
- Tag with appropriate component (`eshu`, `oya`, etc.)
- Be respectful and constructive

## Code of Conduct

Be kind. Be respectful. Build great things together.

We honor the Yoruba traditions that inspired this project - approach discussions with the same reverence and respect.

---

**Thank you for helping build the future of web development!** 🚀
