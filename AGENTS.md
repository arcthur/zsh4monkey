# AGENTS.md

This file provides guidance to coding agents collaborating on this repository.

## Project Overview

zsh4monkey is a modern, feature-rich Zsh configuration framework that provides
zero-config excellence with measured startup performance. It delivers a
powerful shell experience without configuration overhead through intelligent
defaults and optional integrations.

## Project Vision

The de facto standard Zsh configuration framework for developers who want power without complexity.

## Project Requirements

- Always use English in code, examples, and comments
- Features should be implemented concisely, maintainably, and efficiently  
- Code is not just for execution, but also for readability
- Only add meaningful comments and tests
- Maintain backward compatibility and safe upgrade paths
- Prioritize performance and startup speed
- Ensure robust error handling and recovery mechanisms

## Architecture

The project is organized as a Zsh framework with modular components:

### Core Framework
- `main.zsh` - Main initialization and bootstrap logic
- `z4m.zsh` - Primary entry point and user interface
- `.zshenv` - Environment bootstrap (installed in user home)
- `.zshrc` - User configuration template (installed in user home)
- `install` - Interactive and declarative non-interactive installer

### Function Library (`fn/`)
- **Command Functions** (`-z4m-cmd-*`) - Core z4m commands (init, install, ssh, etc.)
- **Initialization Functions** (`-z4m-init-*`) - Plugin and feature initialization
- **Utility Functions** (`-z4m-*`) - Helper functions and utilities
- **ZLE Widgets** (`z4m-*`) - Zsh Line Editor widgets and keybindings
- **Post-install Scripts** (`-z4m-postinstall-*`) - Package-specific setup

### Integration Components
- `sc/` - Shell scripts and bootstrap utilities for SSH deployment and environment setup
- `zb/` - Zsh binary detection and compatibility layer for cross-platform support
- `man/` - Manual pages for z4m commands

### Documentation (`docs/`)
- Comprehensive feature documentation
- Configuration reference
- Integration guides

### Configuration
- `.tmux.conf` - Tmux integration configuration
- `.zshrc.mac` - macOS-specific configuration template

## Common Development Commands

### Zsh Development and Testing

```bash
# Test framework initialization
zsh -c 'source ./z4m.zsh && z4m init'

# Test specific commands
zsh -c 'source ./z4m.zsh && z4m help'

# Check Zsh syntax
for file in main.zsh .zshrc .zshrc.mac fn/*; do
  zsh -n "$file"
done

# Check POSIX bootstrap syntax
for file in .zshenv install z4m.zsh sc/exec-zsh-i sc/setup \
  sc/ssh-bootstrap sc/supply-chain; do
  sh -n "$file"
done

# Run contract and integration tests
for test_file in test/*.zsh; do zsh "$test_file"; done
python3 test/benchmark_startup.py

# Verify locked remote dependencies
sh tools/verify-dependencies
```

### Plugin and Integration Testing

```bash
# Test plugin installation
zsh -c 'source ./z4m.zsh && z4m install fzf'

# Test SSH functionality
zsh -c 'source ./z4m.zsh && z4m ssh --help'

# Test recovery mechanisms
zsh -c 'source ./z4m.zsh && z4m recovery --help'
```

### Documentation and Linting

```bash
# Check manual pages
man -l man/man1/z4m.1

# Validate documentation links
# (check for broken references in docs/)
```

## Key Technical Details

### Security Architecture
- **Authenticated Releases** - GitHub artifact attestation is the independent trust anchor; the SHA-256 sidecar is same-host and covers transport integrity only
- **Pinned Dependencies** - Remote dependencies resolve through exact commits and SHA-256 digests in `dependencies.lock`
- **Archive Validation** - Bootstrap and package extraction reject unsafe paths, link targets, and hard links
- **Data Boundaries** - SSH accepts explicit scalar environment directives and keeps generated payloads data-only
- **Privilege Controls** - Dangerous root detection and controlled privilege escalation
- **Input Validation** - Comprehensive validation of user inputs and external data

### Initialization Flow
1. **Bootstrap** (`~/.zshenv`) - Environment setup and Z4M path configuration
2. **Version Validation** - Zsh 5.9+ requirement check and binary detection
3. **Recovery Check** - Safe mode and recovery shell triggers
4. **Main Framework** (`main.zsh`) - Core module loading and error handling
5. **User Config** (`~/.zshrc`) - Customizations and plugin installation
6. **ZLE Integration** - Interactive features and keybindings setup

### Plugin Management
- **Managed Shell Components** - Powerlevel10k, terminfo, and zsh-completions resolve from the dependency lock
- **Bundled Components** - Autosuggestions and syntax highlighting ship with the framework
- **External Plugins** - GitHub repositories pinned to immutable commits and configured digests
- **CLI Tools** - Optional integrations detect tools such as fzf but do not install or upgrade system binaries

### SSH Teleportation
- **Explicit Environment Directives** - Copies or sets only configured scalar variables
- **Cross-Platform Compatibility** - Supports multiple architectures (darwin x86_64/arm64, linux x86_64/aarch64/armv*)
- **One-Shot Deployment** - Uploads a fresh runtime snapshot without requiring git, zsh, or sudo on the remote
- **Transactional Replacement** - Stages destinations per filesystem and rolls back handled commit failures
- **Failure Boundaries** - Documents that untrappable process or host failure can leave `.z4m-ssh.*` recovery directories

### Recovery and Safety
- **Safe Mode** - Automatic fallback on startup failures with plugin isolation
- **Recovery Shell** - Minimal emergency environment for debugging and recovery
- **Failure Markers** - Tracks initialization failures via `$Z4M/.last-init-failed` marker
- **Recovery Commands** - Specialized functions: `z4m-safe-exit`, `z4m-safe-edit`, `z4m-safe-diagnose`
- **Update Recovery** - `fn/-z4m-recover-update` is the only restore/roll-forward implementation; `z4m update` and the generated temporary bootstrap both call it so the two paths cannot drift

### Intentional Duplication
Bootstrap code runs before `$Z4M` exists, so a few checks are necessarily
implemented more than once. Do not deduplicate them; keep them textually
identical and covered by the tests that pin them together:
- Archive path/link validation: inline in `z4m.zsh` and in `sc/supply-chain` (`test/bootstrap_duplication.zsh`)
- SHA-256 tool chain and preference order: `.zshenv`, `z4m.zsh`, `install`, `sc/supply-chain` (`test/bootstrap_duplication.zsh`)
- `.zshrc` rewrite anchors: `install` constants versus the shipped templates (`test/install_zshrc_anchors.zsh`)

## Development Notes

### Platform Support
- **Supported Architectures** - darwin x86_64/arm64, linux x86_64/aarch64/armv*
- **Binary Detection** - Automatic Zsh binary detection with compatibility layer (`zb/`)
- **Terminal Compatibility** - Support for various terminal capabilities and features

### Zsh-Specific Considerations
- Use `emulate zsh` with appropriate options for compatibility
- Handle different Zsh versions (5.9+ required, with compatibility checks)
- Respect Zsh's parameter expansion and globbing patterns
- Use `zstyle` for configuration rather than environment variables when possible

### Performance Optimization
- Minimize startup time through lazy loading strategies
- Use compiled functions (.zwc) for better performance
- Avoid expensive operations during initialization
- Cache computed values where appropriate
- Measure time to the first fully initialized prompt with `z4m bench`, which
  reports p50 and p95 from PTY-backed runs

### Error Handling
- Implement graceful degradation for missing dependencies
- Provide clear error messages with actionable guidance
- Use recovery mechanisms for non-critical failures
- Validate user inputs and configuration

### Cross-Platform Compatibility
- Support Linux and macOS with platform-specific optimizations
- Handle different terminal capabilities and features
- Account for differences in default utilities and paths
- Test with various Zsh builds and configurations

## Code Standards

### Function Naming
- **Command Functions**: `-z4m-cmd-<name>` - Implement z4m commands
- **Initialization**: `-z4m-init-<feature>` - Initialize specific features  
- **Utilities**: `-z4m-<action>-<object>` - Helper functions
- **ZLE Widgets**: `z4m-<action>` - Interactive widgets
- **Post-install**: `-z4m-postinstall-<package>` - Package setup scripts

### Configuration Patterns
- Use `zstyle` with hierarchical context: `:z4m:<feature>:<subfeature>`
- Provide sensible defaults with opt-out configuration
- Support both boolean and string configuration values
- Use consistent naming patterns across configuration options

### Plugin Integration
- Implement standardized post-install hooks
- Provide graceful fallback when dependencies are missing
- Use feature detection rather than version checking when possible
- Support both standalone and integrated usage patterns

## Review Guidelines

Please note that the attention of contributors and maintainers is the MOST valuable resource.
Less is more: focus on the most important aspects.

- Your review output SHOULD be concise and clear
- You SHOULD only highlight P0 and P1 level issues, such as severe bugs, performance degradation, or security concerns  
- You MUST not reiterate detailed changes in your review
- You MUST not repeat aspects of the PR that are already well done

### Code Quality
- Ensure all new functions have proper error handling
- Validate that startup performance is not degraded
- Check for proper cleanup and resource management
- Verify cross-platform compatibility

### User Experience  
- Maintain backward compatibility for existing configurations
- Ensure error messages are helpful and actionable
- Test recovery mechanisms and safe mode functionality
- Validate that installer works correctly on supported platforms

### Security
- Review SSH teleportation code for security implications
- Ensure proper validation of user inputs and external data
- Check for safe handling of temporary files and paths
- Validate that privilege escalation is properly controlled

### Documentation
- Update relevant documentation sections for new features
- Ensure manual pages reflect command changes
- Add configuration examples for new options
- Update README if user-facing changes are made
