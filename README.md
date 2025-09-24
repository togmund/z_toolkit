# Z-Toolkit: High-Performance Zig Tools for OpenCode

A native Zig implementation of OpenCode tools designed for optimal performance and low CPU usage, starting with the edit tool.

## Overview

This project creates optimized, native implementations of OpenCode's built-in tools using Zig for superior performance. We're starting with the `edit` tool, which currently uses multiple JavaScript-based text replacement strategies that can be CPU-intensive for large files.

## Goals

- **Performance**: Native Zig implementation with optimized algorithms
- **Compatibility**: Drop-in replacement that passes all existing OpenCode tests
- **Maintainability**: Automated workflow to stay in sync with OpenCode updates
- **Extensibility**: Foundation for optimizing other OpenCode tools

## Architecture

### Tool Registration

OpenCode supports custom tools through its plugin system. Tools can be registered by:

1. **Local tools**: Place in `.opencode/tool/` directory
2. **Global tools**: Place in `~/.config/opencode/tool/`
3. **Plugin tools**: Register via the plugin API

The tool registry (`packages/opencode/src/tool/registry.ts`) automatically discovers and loads custom tools, allowing us to override built-in tools with optimized versions.

### Edit Tool Analysis

The current edit tool (`packages/opencode/src/tool/edit.ts`) implements multiple replacement strategies:

1. **SimpleReplacer**: Direct string matching
2. **LineTrimmedReplacer**: Line-by-line matching with trimming
3. **BlockAnchorReplacer**: Block matching with anchor points (disabled)
4. **WhitespaceNormalizedReplacer**: Whitespace-insensitive matching
5. **IndentationFlexibleReplacer**: Indentation-insensitive matching
6. **EscapeNormalizedReplacer**: Escape sequence normalization
7. **TrimmedBoundaryReplacer**: Boundary trimming (disabled)
8. **ContextAwareReplacer**: Context-based matching (disabled)
9. **MultiOccurrenceReplacer**: Multiple occurrence handling (disabled)

Our Zig implementation will optimize these algorithms and potentially implement more efficient pattern matching.

## Implementation Plan

### Phase 1: Core Edit Tool

1. **Zig Library Structure**
   ```
   src/
   ├── main.zig           # Main entry point
   ├── edit/
   │   ├── mod.zig        # Edit module exports
   │   ├── replacers.zig  # Replacement algorithms
   │   └── types.zig      # Type definitions
   ├── common/
   │   ├── errors.zig     # Error handling
   │   └── utils.zig      # Utility functions
   └── ffi/
       └── node.zig       # Node.js FFI bindings
   ```

2. **OpenCode Integration**
   ```
   .opencode/tool/
   └── edit.ts            # Custom edit tool wrapper
   ```

3. **Test Compatibility**
   - Implement all replacement strategies from the original
   - Ensure 100% test suite compatibility
   - Performance benchmarks against original implementation

### Phase 2: Build System & Distribution

1. **Build Configuration**
   - Cross-platform compilation (macOS, Linux, Windows)
   - Shared library output for Node.js FFI
   - Automated builds via GitHub Actions

2. **Installation & Distribution**
   - Bun package for easy installation
   - Binary distribution for different platforms
   - Integration with OpenCode config system

### Phase 3: Sync Workflow

1. **Automated OpenCode Monitoring**
   - GitHub Actions workflow to monitor OpenCode releases
   - Automated test suite updates when OpenCode changes
   - Notification system for breaking changes

2. **Version Management**
   - Semantic versioning aligned with OpenCode releases
   - Compatibility matrix documentation
   - Migration guides for breaking changes

## Technical Details

### Zig Implementation Benefits

1. **Performance**
   - No garbage collection overhead
   - Compile-time optimizations
   - Efficient memory management
   - SIMD optimizations for string operations

2. **Safety**
   - Compile-time null safety
   - Buffer overflow protection
   - Integer overflow detection
   - Memory safety guarantees

3. **Interoperability**
   - Easy C ABI compatibility
   - Node.js N-API integration
   - Cross-platform shared libraries

### Optimization Strategies

1. **String Processing**
   - Boyer-Moore algorithm for pattern matching
   - Optimized Levenshtein distance calculation
   - SIMD-accelerated whitespace normalization
   - Memory-efficient line processing

2. **Algorithm Improvements**
   - Single-pass processing where possible
   - Reduced memory allocations
   - Lazy evaluation of replacement strategies
   - Early termination optimizations

## File Structure

```
z_toolkit/
├── README.md              # This file
├── build.zig              # Zig build configuration
├── src/                   # Zig source code
├── test/                  # Zig tests
├── opencode/              # OpenCode integration
│   └── tool/
│       └── edit.ts        # Custom tool wrapper
├── scripts/               # Build and sync scripts
├── benchmarks/            # Performance benchmarks
└── docs/                  # Documentation
```

## Development Workflow

### Setting Up Development

1. **Clone OpenCode for Reference**
   ```bash
   git submodule add https://github.com/opencode-ai/opencode.git opencode-ref
   ```

2. **Install Dependencies**
   ```bash
   # Zig compiler
   curl https://ziglang.org/download/0.13.0/zig-linux-x86_64-0.13.0.tar.xz | tar -xJ
   
   # Bun for testing and build tools
   bun install
   ```

3. **Build and Test**
   ```bash
   zig build
   bun test
   ```

### Staying in Sync

1. **Monitor OpenCode Changes**
   - Automated GitHub Action checks for new releases
   - Pulls test updates automatically
   - Runs compatibility tests

2. **Update Process**
   ```bash
   # Update OpenCode reference
   cd opencode-ref && git pull origin main
   
   # Run compatibility tests
   bun run test:compatibility
   
   # Update implementation if needed
   zig build test
   ```

## Testing Strategy

### Test Categories

1. **Unit Tests** (Zig)
   - Individual replacer algorithms
   - Edge case handling
   - Performance benchmarks

2. **Integration Tests** (Node.js)
   - OpenCode tool API compatibility
   - Full edit operation workflows
   - Error handling

3. **Compatibility Tests**
   - All existing OpenCode edit tool tests
   - Regression testing against known issues
   - Cross-platform validation

### Continuous Integration

```yaml
# .github/workflows/test.yml
name: Test Suite
on: [push, pull_request]
jobs:
  test:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - name: Setup Zig
        uses: goto-bus-stop/setup-zig@v2
      - name: Build
        run: zig build
      - name: Test Zig
        run: zig build test
      - name: Test Node.js Integration
        run: bun test
```

## Performance Goals

### Target Improvements

- **Latency**: 50-80% reduction in edit operation time
- **Memory**: 60-70% reduction in peak memory usage  
- **CPU**: 40-60% reduction in CPU utilization
- **Throughput**: 3-5x improvement for large file operations

### Benchmarking

Regular benchmarks against:
- Original OpenCode edit tool
- Standard text editors (VS Code, Vim)
- Other text processing tools

## Contributing

1. **Code Style**: Follow Zig style guidelines
2. **Testing**: All changes must pass existing test suite
3. **Performance**: Include benchmark results for significant changes
4. **Documentation**: Update docs for API changes

## License

MIT License - Same as OpenCode to ensure compatibility.

## Roadmap

### v0.1.0 - MVP Edit Tool
- [ ] Core Zig implementation
- [ ] Node.js FFI integration
- [ ] Pass all OpenCode edit tests
- [ ] Basic performance improvements

### v0.2.0 - Optimization
- [ ] Advanced algorithm optimizations
- [ ] SIMD acceleration
- [ ] Memory usage improvements
- [ ] Comprehensive benchmarks

### v0.3.0 - Additional Tools
- [ ] Grep tool optimization
- [ ] Glob tool optimization  
- [ ] Read/Write tool optimization
- [ ] Plugin architecture

### v1.0.0 - Production Ready
- [ ] Full tool suite
- [ ] Automated OpenCode sync
- [ ] Production deployment
- [ ] Documentation complete

## Getting Started

```bash
# Clone the repository
git clone <repo-url> z_toolkit
cd z_toolkit

# Initialize OpenCode reference
git submodule update --init --recursive

# Build the Zig library
zig build

# Run tests
bun test

# Install as OpenCode tool
bun run install:opencode
```

This toolkit represents a significant step toward making OpenCode faster and more efficient while maintaining full compatibility with existing workflows.