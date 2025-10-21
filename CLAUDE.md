# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

ConfigOMat (config_o_mat) is a Ruby gem that manages runtime configuration of systemd services by:
1. Reading configuration data from AWS AppConfig and AWS Secrets Manager
2. Rendering ERB templates with that data
3. Restarting systemd services to apply configuration updates

The system polls AWS AppConfig on a configurable interval and applies configuration changes atomically.

## Working with Claude Code

### Git Workflow

**Branch Naming**: Use prefixes to categorize work:
- `feat/` - New features
- `maint/` - Maintenance tasks (CI, dependencies, tooling)
- `fix/` - Bug fixes

Branch names should be short and succinct (e.g., `maint/ci-setup`, `feat/metrics`, `fix/retry-logic`).

**Commit Messages**: When Claude creates commits, include the complete verbatim user prompts that led to the changes. This helps other users understand how to effectively work with Claude by seeing real interaction examples.

### Text Artifacts

All text artifacts (planning documents, commit messages, branch names, documentation updates, etc.) should be:
- **Short and concise** - Get to the point quickly
- **Non-duplicative** - Don't restate what's visible in nearby context (e.g., commit messages shouldn't repeat the diff)
- **Focused on "why" over "what"** - The code/diff shows what changed; explain the reasoning

## Development Commands

### Running Tests
```bash
bundle exec rake spec                    # Run all tests
bundle exec rspec spec/path/to/spec.rb   # Run a single test file
bundle exec rspec spec/path/to/spec.rb:42 # Run test at specific line
```

### Building and Installing
```bash
bundle install                           # Install dependencies
bundle exec rake build                   # Build the gem
bundle exec rake install                 # Install the gem locally
bundle exec rake release                 # Release new version (bumps version, tags, pushes)
```

### Documentation
```bash
bundle exec rake doc                     # Generate YARD documentation
```

### Code Coverage
Tests use SimpleCov with branch coverage enabled. Coverage reports are generated automatically when running specs.

## Architecture

### State Machine Pattern (LifecycleVM)

The codebase uses the `lifecycle_vm` gem to implement behavior as finite state machines. Each major component is a VM (Virtual Machine) that defines states, operations, and transitions:

- **Configurator::VM** (`lib/config_o_mat/configurator.rb`) - Main configuration management lifecycle
- **MetaConfigurator::VM** (`lib/config_o_mat/meta_configurator.rb`) - Generates systemd unit files from meta-config
- **FlipFlopper::VM** (`lib/config_o_mat/flip_flopper.rb`) - Manages flip-flop service restarts (instantiated units @1 and @2)
- **SecretsLoader::VM** (`lib/config_o_mat/secrets_loader.rb`) - Loads secrets from AWS Secrets Manager

Each VM has:
- **Memory class** - Holds all state for the VM (immutable state pattern)
- **Op (Operations)** - Actions that execute and modify state (in `op/` subdirectories)
- **Cond (Conditions)** - Decision points that determine state transitions (in `cond/` subdirectories)

### Core Workflow (Configurator::VM)

1. **Parse CLI** → Parse command-line arguments
2. **Load Meta Config** → Read and merge all `.conf` files from config directory
3. **Compile Templates** → Load and compile ERB templates
4. **Connect to AWS** → Initialize AWS SDK clients (AppConfig, Secrets Manager, S3)
5. **Refresh Profiles** → Poll AWS AppConfig for configuration updates
6. **Apply Profiles** → Process updated profiles and load any referenced secrets
7. **Generate Templates** → Render ERB templates with profile data
8. **Reload Services** → Restart affected systemd services
9. **Running** → Sleep until next refresh interval, then loop back to refresh

### Configuration Types (lib/config_o_mat/shared/types.rb)

The system defines several key configuration objects:
- **Profile** - AWS AppConfig profile definition (application, environment, profile name)
- **Template** - ERB template file mapping (src → dst)
- **Service** - Systemd service with restart mode (`restart`, `flip_flop`, `restart_all`, `none`)
- **Secret** - AWS Secrets Manager secret definition with parsing instructions
- **LoadedAppconfigProfile** - Loaded profile data with parsed content (JSON/YAML/text)
- **LoadedSecret** - Loaded secret data from AWS Secrets Manager
- **FacterProfile** - System facts from the Facter gem

### Restart Modes

Services can use different restart strategies:
- **restart** - Standard systemd try-reload-or-restart
- **flip_flop** - Zero-downtime restart using instantiated units (@1 and @2)
- **restart_all** - Restart all instances of an instantiated unit template
- **none** - Only update files, don't restart

### Error Handling and Retry Logic

The Configurator VM includes retry logic:
- On first run, any operation failure causes the VM to fail immediately
- After first run, failures trigger retry with exponential backoff
- Configurable via `retry_count` and `retry_wait` in config files
- Failed profile refreshes can roll back to previous working version

### Secrets Integration

Profiles can reference secrets via the `aws:secrets` key in their configuration. The SecretsLoader VM:
1. Identifies secrets to load from staged profiles
2. Checks an in-memory cache to avoid unnecessary AWS calls
3. Loads secrets from AWS Secrets Manager
4. Parses secrets according to content_type (JSON/YAML/text)
5. Makes secrets available to ERB templates

### Testing Pattern

Tests use RSpec with:
- `spec_helper.rb` configures SimpleCov, shared contexts, and Facter mocking
- Tests are organized by component: `configurator/`, `flip_flopper/`, `secrets_loader/`, `meta_configurator/`, `shared/`
- Each Op and Cond has corresponding spec files
- Shared context `'with a logger'` provides test logger for specs tagged with `logger: true`
- Facter is mocked by default with fixture data from `spec/fixtures/facter/default`

### Operations (Op) Pattern

When adding new operations:
- Inherit from `LifecycleVM::OpBase`
- Declare `reads` for memory fields to read
- Declare `writes` for memory fields to modify
- Implement `call` method
- Use `error(field, message)` to record errors
- Return early if `errors?` is true

### Conditions (Cond) Pattern

When adding new conditions:
- Inherit from `LifecycleVM::CondBase`
- Declare `reads` for memory fields to read
- Implement `call` to return the decision value
- Must return a value that matches a key in the VM's state transition map

## Configuration File Format

Meta-configuration files (`.conf` in YAML):
```yaml
log_level: debug|info|notice|warn|error
log_type: stdout|file
log_file: path/to/file.log
refresh_interval: 5  # seconds
retry_count: 3
retry_wait: 2  # seconds
region: us-east-1
gc_compact: 0  # number of ticks between GC compacts (0 = disabled)
gc_stat: 0     # number of ticks between GC stat logs (0 = disabled)
fallback_s3_bucket: bucket-name  # Required if any profile uses s3_fallback

profiles:
  profile_name:
    application: app-name
    environment: env-name
    profile: profile-name
    s3_fallback: s3-key-prefix  # Optional S3 fallback location

templates:
  template_name:
    src: source/path.erb
    dst: destination/path

services:
  service_name:
    systemd_unit: unit-name
    restart_mode: restart|flip_flop|restart_all|none
    templates:
      - template_name

facter: profile_name  # Enable Facter profile with given name
```

Multiple `.conf` files are deep-merged in lexical order.

## File Organization

- `bin/` - Executable entry points
- `lib/config_o_mat/` - Main source code
  - `configurator/` - Main configuration management VM
  - `meta_configurator/` - Systemd config generation VM
  - `flip_flopper/` - Zero-downtime restart VM
  - `secrets_loader/` - AWS Secrets Manager integration VM
  - `shared/` - Shared operations, conditions, and types
- `spec/` - RSpec tests mirroring lib structure
- `design/` - Original design documentation

## Dependencies

Key external dependencies:
- `lifecycle_vm` - State machine framework
- `aws-sdk-appconfig` - AWS AppConfig client
- `aws-sdk-secretsmanager` - AWS Secrets Manager client
- `aws-sdk-s3` - S3 client for fallback configurations
- `ruby-dbus` - systemd communication via D-Bus
- `sd_notify` - systemd watchdog notifications
- `facter` - System fact collection
- `logsformyfamily` - Structured JSON logging

## Ruby Version

Requires Ruby >= 2.7.0 (see `.ruby-version` and gemspec for current version).
