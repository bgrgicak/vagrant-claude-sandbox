# Testing Locally

## Quick Start

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
vagrant ssh
# Inside VM: test docker, node, claude, claude-yolo
exit
vagrant destroy -f
```

## Prerequisites

- Vagrant >= 2.2.0
- VirtualBox >= 6.1
- Ruby >= 2.6.0

## Build and Install

```bash
gem build vagrant-claude-sandbox.gemspec
vagrant plugin install vagrant-claude-sandbox-0.1.0.gem
vagrant plugin list  # Verify installation
```

## Test Scenarios

### Basic Functionality

```bash
mkdir ~/test-claude-sandbox && cd ~/test-claude-sandbox
echo "console.log('test');" > test.js
cat > Vagrantfile << 'EOF'
Vagrant.configure("2") do |config|
  config.claude_sandbox.apply_to!(config)
end
EOF

vagrant up
vagrant ssh -c "node /agent-workspace/test.js"  # Should output: test
vagrant destroy -f
```

### Custom Configuration

```ruby
# Vagrantfile
Vagrant.configure("2") do |config|
  config.claude_sandbox.apply_to!(config) do |sandbox|
    sandbox.memory = 8192
    sandbox.cpus = 4
    sandbox.additional_packages = ["vim", "htop"]
  end
end
```

Verify:
```bash
vagrant up && vagrant ssh
free -h    # ~8GB RAM
nproc      # 4 CPUs
which vim  # Exists
exit && vagrant destroy -f
```

### Docker Test

```bash
vagrant up && vagrant ssh
docker run hello-world
exit
```

### Claude Config Sync

```bash
ls -la ~/.claude/  # Ensure exists on host
vagrant up && vagrant ssh
ls -la ~/.claude/  # Should be synced
```

## Update and Retest

```bash
# Make changes, then:
gem build vagrant-claude-sandbox.gemspec
vagrant plugin uninstall vagrant-claude-sandbox
vagrant plugin install vagrant-claude-sandbox-0.1.0.gem
vagrant up
```

## Automated Test Script

Save as `test-plugin.sh`:

```bash
#!/bin/bash
set -e

echo "Building and testing plugin..."
gem build vagrant-claude-sandbox.gemspec
vagrant plugin uninstall vagrant-claude-sandbox 2>/dev/null || true
vagrant plugin install vagrant-claude-sandbox-*.gem

mkdir -p /tmp/vagrant-test-$$
cd /tmp/vagrant-test-$$

cat > Vagrantfile << 'EOF'
Vagrant.configure("2") do |config|
  config.claude_sandbox.apply_to!(config)
end
EOF

vagrant up
vagrant ssh -c "docker --version && node --version && claude --version && which claude-yolo"
vagrant destroy -f

cd - && rm -rf /tmp/vagrant-test-$$
echo "Test complete!"
```

Run:
```bash
chmod +x test-plugin.sh
./test-plugin.sh
```
