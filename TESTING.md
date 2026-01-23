# Testing Locally

## Quick Start

### VirtualBox (Default)

```bash
# Build and install
gem build vagrant-claude-sandbox.gemspec
vagrant plugin install vagrant-claude-sandbox-0.1.0.gem

# Create test project
mkdir test-project && cd test-project
cat > Vagrantfile << 'EOF'
Vagrant.configure("2") do |config|
  config.claude_sandbox.apply_to!(config)
end
EOF

# Test
vagrant up
vagrant claude  # Launches Claude CLI automatically
# Verify Claude works, then exit
exit
vagrant destroy -f
```

### Docker Provider

```bash
# Build and install (if not already done)
gem build vagrant-claude-sandbox.gemspec
vagrant plugin install vagrant-claude-sandbox-0.1.0.gem

# Create test project
mkdir test-docker && cd test-docker
cat > Vagrantfile << 'EOF'
Vagrant.configure("2") do |config|
  config.claude_sandbox.provider = "docker"
  config.claude_sandbox.apply_to!(config)
end
EOF

# Test
vagrant up --provider=docker
vagrant claude  # Launches Claude CLI automatically
# Verify Claude works, then exit
exit
vagrant destroy -f
```

## Automated Test Suite

### Integration Tests

The `test-plugin.sh` script provides comprehensive integration testing:

```bash
# Test all providers with all tests (VirtualBox and Docker)
./test-plugin.sh

# Test VirtualBox only
./test-plugin.sh virtualbox

# Test Docker only
./test-plugin.sh docker

# Test all providers, skip extended tests (faster)
./test-plugin.sh all --skip-extended

# Show usage
./test-plugin.sh --help
```

**What gets tested:**

Basic tests (always run):
- Plugin build and installation
- VM/container startup
- Node.js and Claude CLI installation
- Workspace and Claude config mounting
- Plugin path fixing
- Docker installation (VirtualBox only)

Extended tests (run by default, skip with `--skip-extended`):
- Custom memory and CPU configuration
- Additional packages installation
- Handling missing Claude config directory
- skip_claude_cli_install option
- `vagrant claude` command functionality
- Idempotency (running `vagrant up` twice)

### Unit Tests

Run RSpec unit tests for Ruby code validation:

```bash
# Install dependencies
bundle install

# Run unit tests only
bundle exec rake spec

# Run unit tests with verbose output
bundle exec rspec spec/unit --format documentation

# Run all tests (unit + integration)
bundle exec rake test
```

**What gets tested:**

Unit tests cover:
- Config class validation (memory, cpus, provider, additional_packages)
- Config default values and custom values
- Provisioning script generation
- PathFixer PATH conflict detection and resolution
- Docker binary discovery
- Command class SSH execution and workspace path handling

## Test Custom Configuration

### VirtualBox with Custom Settings

```bash
cat > Vagrantfile << 'EOF'
Vagrant.configure("2") do |config|
  config.claude_sandbox.memory = 8192
  config.claude_sandbox.cpus = 4
  config.claude_sandbox.additional_packages = ["vim", "htop"]
  config.claude_sandbox.apply_to!(config)
end
EOF

vagrant up && vagrant ssh
# Inside VM: verify with 'free -h', 'nproc', 'which vim', 'which htop'
exit && vagrant destroy -f
```

### Docker with Custom Settings

```bash
cat > Vagrantfile << 'EOF'
Vagrant.configure("2") do |config|
  config.claude_sandbox.provider = "docker"
  config.claude_sandbox.memory = 8192
  config.claude_sandbox.cpus = 4
  config.claude_sandbox.additional_packages = ["vim", "htop"]
  config.claude_sandbox.apply_to!(config)
end
EOF

vagrant up --provider=docker && vagrant ssh
# Inside container: verify with 'which vim', 'which htop'
exit && vagrant destroy -f
```

### Docker with Custom Image

```bash
cat > Vagrantfile << 'EOF'
Vagrant.configure("2") do |config|
  config.claude_sandbox.provider = "docker"
  config.claude_sandbox.docker_image = "my-custom-ssh-image:latest"
  config.claude_sandbox.apply_to!(config)
end
EOF

vagrant up --provider=docker && vagrant ssh
exit && vagrant destroy -f
```

**Note**: Custom images must have SSH configured and a `vagrant` user with sudo access.

## Test Plugin and Skills Support

If you have Claude plugins or skills installed:

```bash
vagrant up  # or: vagrant up --provider=docker

# Verify Claude config was copied
vagrant ssh -c "ls -la ~/.claude/"
vagrant ssh -c "ls ~/.claude/plugins/"

# Verify plugin paths were fixed
vagrant ssh -c "cat ~/.claude/plugins/installed_plugins.json"
# Paths should be /home/vagrant/.claude/... not your host paths

# Test Claude with your skills
vagrant claude
# Try using one of your installed skills, then exit

vagrant destroy -f
```

## Provider Comparison

| Feature | VirtualBox | Docker |
|---------|------------|--------|
| Full VM isolation | Yes | No (container) |
| Docker inside | Yes (installed) | No (skipped) |
| Startup speed | Slower | Faster |
| Resource usage | Higher | Lower |
| SSH access | Yes | Yes |
| Synced folders | Yes | Yes |
| Claude CLI | Yes | Yes |

## Troubleshooting

### General

- **Plugin not loading**: `vagrant plugin list`
- **Config not syncing**: Ensure `~/.claude/` exists
- **Permission issues**: `vagrant destroy && vagrant up`
- **Rebuild after changes**: Uninstall, rebuild gem, reinstall plugin

### VirtualBox Specific

- **Provisioning fails**: `VBoxManage --version`
- **VM won't start**: Check VirtualBox is running, no conflicting VMs

### Docker Specific

- **Container won't start**: `docker ps -a` to check status
- **SSH connection fails**: Ensure Docker daemon is running
- **Build fails**: Check Docker has sufficient resources
- **Permission denied**: Ensure user is in docker group (`sudo usermod -aG docker $USER`)

## Manual Provider Testing

### Verify VirtualBox Configuration

```bash
vagrant up
vagrant ssh -c "docker --version"  # Should work in VirtualBox
vagrant ssh -c "node --version"
vagrant ssh -c ". ~/.nvm/nvm.sh && claude --version"
vagrant destroy -f
```

### Verify Docker Configuration

```bash
vagrant up --provider=docker
vagrant ssh -c "docker --version 2>/dev/null || echo 'Docker not installed (expected in Docker provider)'"
vagrant ssh -c "cat /etc/os-release"  # Should show Ubuntu 24.04
vagrant ssh -c "node --version"
vagrant ssh -c ". ~/.nvm/nvm.sh && claude --version"
vagrant destroy -f
```
