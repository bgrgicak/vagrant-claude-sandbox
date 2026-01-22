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
# Inside VM: verify docker, node, claude, claude-yolo
exit
vagrant destroy -f
```

## Test Custom Configuration

```bash
# Create Vagrantfile with custom settings
cat > Vagrantfile << 'EOF'
Vagrant.configure("2") do |config|
  config.claude_sandbox.apply_to!(config) do |sandbox|
    sandbox.memory = 8192
    sandbox.cpus = 4
    sandbox.additional_packages = ["vim", "htop"]
  end
end
EOF

vagrant up && vagrant ssh
# Verify: free -h, nproc, which vim, which htop
exit && vagrant destroy -f
```

## Test Plugin and Skills Support

If you have Claude plugins or skills installed:

```bash
vagrant up
vagrant ssh

# Inside VM: check if Claude config was copied
ls -la ~/.claude/

# Check if plugins are loaded (if you have any installed)
ls ~/.claude/plugins/

# Verify plugin paths were fixed
cat ~/.claude/plugins/installed_plugins.json
# Paths should be /home/vagrant/.claude/... not your host paths

# Test that claude-yolo works with your skills
claude-yolo
# Try using one of your installed skills

exit
vagrant destroy -f
```

## Automated Test Script

Save as `test-plugin.sh`:

```bash
#!/bin/bash
set -e

# Build and install
gem build vagrant-claude-sandbox.gemspec
vagrant plugin uninstall vagrant-claude-sandbox 2>/dev/null || true
vagrant plugin install vagrant-claude-sandbox-*.gem

# Test
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

Run: `chmod +x test-plugin.sh && ./test-plugin.sh`

## Troubleshooting

**Plugin not loading**: `vagrant plugin list`
**Provisioning fails**: `VBoxManage --version`
**Config not syncing**: Ensure `~/.claude/` exists
**Permission issues**: `vagrant destroy && vagrant up`
**Rebuild after changes**: Uninstall, rebuild gem, reinstall plugin
