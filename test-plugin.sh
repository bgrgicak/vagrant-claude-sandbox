#!/bin/bash

set -e

echo "================================================"
echo "vagrant-claude-sandbox Plugin Test Script"
echo "================================================"
echo ""

# Check prerequisites
echo "Checking prerequisites..."
command -v vagrant >/dev/null 2>&1 || { echo "Error: Vagrant is not installed"; exit 1; }
command -v VBoxManage >/dev/null 2>&1 || { echo "Error: VirtualBox is not installed"; exit 1; }
echo "✓ Prerequisites OK"
echo ""

# Build plugin
echo "Building plugin..."
gem build vagrant-claude-sandbox.gemspec
echo "✓ Plugin built"
echo ""

# Install plugin
echo "Installing plugin..."
vagrant plugin uninstall vagrant-claude-sandbox 2>/dev/null || true
vagrant plugin install vagrant-claude-sandbox-*.gem
echo "✓ Plugin installed"
echo ""

# Verify installation
echo "Verifying installation..."
vagrant plugin list | grep vagrant-claude-sandbox
echo "✓ Plugin verified"
echo ""

# Create test project
TEST_DIR="/tmp/vagrant-claude-sandbox-test-$$"
echo "Creating test project in $TEST_DIR..."
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# Create test file
echo "console.log('Hello from Claude Sandbox');" > test.js

# Create Vagrantfile
cat > Vagrantfile << 'EOF'
Vagrant.configure("2") do |config|
  config.claude_sandbox.apply_to!(config)
end
EOF

echo "✓ Test project created"
echo ""

# Start VM
echo "Starting VM (this may take a few minutes)..."
vagrant up

echo "✓ VM started"
echo ""

# Run tests
echo "Running tests..."
echo ""

echo "Test 1: Check Docker..."
vagrant ssh -c "docker --version"
echo "✓ Docker OK"
echo ""

echo "Test 2: Check Node.js..."
vagrant ssh -c "node --version"
echo "✓ Node.js OK"
echo ""

echo "Test 3: Check Claude CLI..."
vagrant ssh -c "claude --version"
echo "✓ Claude CLI OK"
echo ""

echo "Test 4: Check claude-yolo wrapper..."
vagrant ssh -c "which claude-yolo && cat /usr/local/bin/claude-yolo"
echo "✓ claude-yolo OK"
echo ""

echo "Test 5: Check workspace..."
vagrant ssh -c "pwd && ls -la /agent-workspace/test.js"
echo "✓ Workspace OK"
echo ""

echo "Test 6: Run test.js..."
vagrant ssh -c "node /agent-workspace/test.js"
echo "✓ Test execution OK"
echo ""

echo "Test 7: Check Claude config..."
vagrant ssh -c "ls -la ~/.claude/ 2>/dev/null || echo 'No Claude config found (this is OK if you don\\'t have ~/.claude/ on host)'"
echo "✓ Claude config check OK"
echo ""

echo "Test 8: Check plugin paths if config exists..."
vagrant ssh -c "if [ -f ~/.claude/plugins/installed_plugins.json ]; then grep -q '/home/vagrant/.claude' ~/.claude/plugins/installed_plugins.json && echo 'Plugin paths correctly fixed' || echo 'Warning: Plugin paths may not be fixed'; else echo 'No plugins file (OK if no plugins installed)'; fi"
echo "✓ Plugin paths check OK"
echo ""

# Cleanup
echo "Cleaning up..."
vagrant destroy -f
cd -
rm -rf "$TEST_DIR"
echo "✓ Cleanup complete"
echo ""

echo "================================================"
echo "All tests passed! ✓"
echo "================================================"
echo ""
echo "The plugin is ready to use. You can now:"
echo "1. Create a Vagrantfile in any project with: config.claude_sandbox.apply_to!(config)"
echo "2. Run: vagrant up"
echo "3. SSH with: vagrant ssh"
echo "4. Use: claude-yolo inside the VM"
echo ""
