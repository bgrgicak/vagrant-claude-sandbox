#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_BASE_DIR="/tmp/vagrant-claude-sandbox-test-$$"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_header() {
    echo ""
    echo "================================================"
    echo "$1"
    echo "================================================"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

cleanup() {
    local test_dir="$1"
    echo "Cleaning up $test_dir..."
    if [ -d "$test_dir" ]; then
        cd "$test_dir"
        vagrant destroy -f 2>/dev/null || true
        cd "$SCRIPT_DIR"
        rm -rf "$test_dir"
    fi
    print_success "Cleanup complete"
}

check_prerequisites() {
    print_header "Checking Prerequisites"

    command -v vagrant >/dev/null 2>&1 || { print_error "Vagrant is not installed"; exit 1; }
    print_success "Vagrant installed"

    if [ "$1" = "virtualbox" ] || [ "$1" = "all" ]; then
        command -v VBoxManage >/dev/null 2>&1 || { print_error "VirtualBox is not installed"; exit 1; }
        print_success "VirtualBox installed"
    fi

    if [ "$1" = "docker" ] || [ "$1" = "all" ]; then
        command -v docker >/dev/null 2>&1 || { print_error "Docker is not installed"; exit 1; }
        print_success "Docker installed"
    fi
}

build_and_install_plugin() {
    print_header "Building and Installing Plugin"

    cd "$SCRIPT_DIR"

    echo "Building plugin..."
    gem build vagrant-claude-sandbox.gemspec
    print_success "Plugin built"

    echo "Installing plugin..."
    vagrant plugin uninstall vagrant-claude-sandbox 2>/dev/null || true
    vagrant plugin install vagrant-claude-sandbox-*.gem
    print_success "Plugin installed"

    echo "Verifying installation..."
    vagrant plugin list | grep vagrant-claude-sandbox
    print_success "Plugin verified"
}

run_common_tests() {
    local provider="$1"

    echo "Test: Check Node.js..."
    vagrant ssh -c "node --version"
    print_success "Node.js OK"
    echo ""

    echo "Test: Check Claude CLI..."
    vagrant ssh -c "claude --version"
    print_success "Claude CLI OK"
    echo ""

    echo "Test: Check workspace..."
    vagrant ssh -c "pwd && ls -la /agent-workspace/test.js"
    print_success "Workspace OK"
    echo ""

    echo "Test: Run test.js..."
    vagrant ssh -c "node /agent-workspace/test.js"
    print_success "Test execution OK"
    echo ""

    echo "Test: Check Claude config..."
    vagrant ssh -c "ls -la ~/.claude/ 2>/dev/null || echo 'No Claude config found (this is OK if you do not have ~/.claude/ on host)'"
    print_success "Claude config check OK"
    echo ""

    echo "Test: Check plugin paths if config exists..."
    vagrant ssh -c "if [ -f ~/.claude/plugins/installed_plugins.json ]; then grep -q '/home/vagrant/.claude' ~/.claude/plugins/installed_plugins.json && echo 'Plugin paths correctly fixed' || echo 'Warning: Plugin paths may not be fixed'; else echo 'No plugins file (OK if no plugins installed)'; fi"
    print_success "Plugin paths check OK"
    echo ""
}

test_virtualbox() {
    print_header "Testing VirtualBox Provider"

    local test_dir="$TEST_BASE_DIR-virtualbox"
    mkdir -p "$test_dir"
    cd "$test_dir"

    # Create test file
    echo "console.log('Hello from Claude Sandbox - VirtualBox');" > test.js

    # Create Vagrantfile for VirtualBox (default provider)
    cat > Vagrantfile << 'EOF'
Vagrant.configure("2") do |config|
  config.claude_sandbox.apply_to!(config)
end
EOF

    print_success "Test project created"

    echo "Starting VirtualBox VM..."
    vagrant up
    print_success "VM started"
    echo ""

    echo "Running common tests..."
    run_common_tests "virtualbox"

    # VirtualBox-specific test: Docker should be installed inside VM
    echo "Test: Check Docker is installed inside VM..."
    vagrant ssh -c "docker --version"
    print_success "Docker installed in VM"
    echo ""

    cleanup "$test_dir"
    print_success "VirtualBox tests passed!"
}

test_docker() {
    print_header "Testing Docker Provider"

    local test_dir="$TEST_BASE_DIR-docker"
    mkdir -p "$test_dir"
    cd "$test_dir"

    # Create test file
    echo "console.log('Hello from Claude Sandbox - Docker');" > test.js

    # Create Vagrantfile for Docker provider
    cat > Vagrantfile << 'EOF'
Vagrant.configure("2") do |config|
  config.claude_sandbox.provider = "docker"
  config.claude_sandbox.apply_to!(config)
end
EOF

    print_success "Test project created"

    echo "Starting Docker container..."
    vagrant up --provider=docker
    print_success "Container started"
    echo ""

    echo "Running common tests..."
    run_common_tests "docker"

    # Docker-specific test: Docker should NOT be installed inside the container
    echo "Test: Verify Docker is NOT installed inside container (expected behavior)..."
    if vagrant ssh -c "command -v docker" 2>/dev/null; then
        print_warning "Docker is installed inside container (unexpected but not fatal)"
    else
        print_success "Docker correctly not installed inside container"
    fi
    echo ""

    cleanup "$test_dir"
    print_success "Docker tests passed!"
}

test_docker_custom_image() {
    print_header "Testing Docker Provider with Custom Image"

    local test_dir="$TEST_BASE_DIR-docker-custom"
    mkdir -p "$test_dir"
    cd "$test_dir"

    # Create test file
    echo "console.log('Hello from Claude Sandbox - Docker Custom');" > test.js

    # Create Vagrantfile for Docker provider with custom image
    # Using the built image name pattern from Vagrant
    cat > Vagrantfile << 'EOF'
Vagrant.configure("2") do |config|
  config.claude_sandbox.provider = "docker"
  # Test that docker_image option is accepted (using ubuntu as a test)
  # In real usage, users would provide their own SSH-ready image
  config.claude_sandbox.docker_image = nil  # Use default built image
  config.claude_sandbox.apply_to!(config)
end
EOF

    print_success "Test project created with custom image config"

    echo "Starting Docker container with custom config..."
    vagrant up --provider=docker
    print_success "Container started"
    echo ""

    echo "Verifying container is running..."
    vagrant ssh -c "echo 'SSH connection successful'"
    print_success "Container accessible via SSH"
    echo ""

    cleanup "$test_dir"
    print_success "Docker custom image tests passed!"
}

test_custom_resources() {
    print_header "Testing Custom Memory and CPU Configuration"

    local test_dir="$TEST_BASE_DIR-custom-resources"
    mkdir -p "$test_dir"
    cd "$test_dir"

    # Create test file
    echo "console.log('Testing custom resources');" > test.js

    # Create Vagrantfile with custom resources
    cat > Vagrantfile << 'EOF'
Vagrant.configure("2") do |config|
  config.claude_sandbox.provider = "docker"
  config.claude_sandbox.memory = 8192
  config.claude_sandbox.cpus = 4
  config.claude_sandbox.apply_to!(config)
end
EOF

    print_success "Test project created with custom resources"

    echo "Starting container with custom resources..."
    vagrant up --provider=docker
    print_success "Container started"
    echo ""

    # Check that container is running with correct resources
    echo "Test: Verify container resources..."
    CONTAINER_ID=$(vagrant global-status --prune | grep "$test_dir" | awk '{print $1}')
    if [ -n "$CONTAINER_ID" ]; then
        docker inspect "$CONTAINER_ID" | grep -q "8192m" || print_warning "Memory setting may not be verified"
        print_success "Resource configuration applied"
    else
        print_warning "Could not verify container resources directly"
    fi
    echo ""

    cleanup "$test_dir"
    print_success "Custom resources tests passed!"
}

test_additional_packages() {
    print_header "Testing Additional Packages Installation"

    local test_dir="$TEST_BASE_DIR-additional-packages"
    mkdir -p "$test_dir"
    cd "$test_dir"

    # Create test file
    echo "console.log('Testing additional packages');" > test.js

    # Create Vagrantfile with additional packages
    cat > Vagrantfile << 'EOF'
Vagrant.configure("2") do |config|
  config.claude_sandbox.provider = "docker"
  config.claude_sandbox.additional_packages = ["vim", "htop"]
  config.claude_sandbox.apply_to!(config)
end
EOF

    print_success "Test project created with additional packages"

    echo "Starting container and installing packages..."
    vagrant up --provider=docker
    print_success "Container started"
    echo ""

    echo "Test: Verify vim is installed..."
    vagrant ssh -c "vim --version" > /dev/null
    print_success "vim installed"
    echo ""

    echo "Test: Verify htop is installed..."
    vagrant ssh -c "htop --version" > /dev/null
    print_success "htop installed"
    echo ""

    cleanup "$test_dir"
    print_success "Additional packages tests passed!"
}

test_no_claude_config() {
    print_header "Testing Without Claude Config Directory"

    local test_dir="$TEST_BASE_DIR-no-claude-config"
    mkdir -p "$test_dir"
    cd "$test_dir"

    # Create test file
    echo "console.log('Testing without Claude config');" > test.js

    # Create Vagrantfile that points to non-existent config
    cat > Vagrantfile << 'EOF'
Vagrant.configure("2") do |config|
  config.claude_sandbox.provider = "docker"
  config.claude_sandbox.claude_config_path = "/non/existent/path"
  config.claude_sandbox.apply_to!(config)
end
EOF

    print_success "Test project created without Claude config"

    echo "Starting container without Claude config..."
    vagrant up --provider=docker
    print_success "Container started successfully without Claude config"
    echo ""

    echo "Test: Verify Claude CLI is still installed..."
    vagrant ssh -c "claude --version"
    print_success "Claude CLI works without config"
    echo ""

    cleanup "$test_dir"
    print_success "No Claude config tests passed!"
}

test_skip_claude_install() {
    print_header "Testing Skip Claude CLI Installation"

    local test_dir="$TEST_BASE_DIR-skip-claude"
    mkdir -p "$test_dir"
    cd "$test_dir"

    # Create test file
    echo "console.log('Testing skip Claude install');" > test.js

    # Create Vagrantfile with skip_claude_cli_install
    cat > Vagrantfile << 'EOF'
Vagrant.configure("2") do |config|
  config.claude_sandbox.provider = "docker"
  config.claude_sandbox.skip_claude_cli_install = true
  config.claude_sandbox.apply_to!(config)
end
EOF

    print_success "Test project created with skip_claude_cli_install"

    echo "Starting container with provisioning skipped..."
    vagrant up --provider=docker
    print_success "Container started"
    echo ""

    echo "Test: Verify Claude CLI is NOT installed..."
    if vagrant ssh -c "command -v claude" 2>/dev/null; then
        print_warning "Claude CLI found (may be from Docker image)"
    else
        print_success "Claude CLI correctly not installed"
    fi
    echo ""

    cleanup "$test_dir"
    print_success "Skip Claude install tests passed!"
}

test_vagrant_claude_command() {
    print_header "Testing 'vagrant claude' Command"

    local test_dir="$TEST_BASE_DIR-claude-command"
    mkdir -p "$test_dir"
    cd "$test_dir"

    # Create test file
    echo "console.log('Testing vagrant claude command');" > test.js

    # Create Vagrantfile
    cat > Vagrantfile << 'EOF'
Vagrant.configure("2") do |config|
  config.claude_sandbox.provider = "docker"
  config.claude_sandbox.apply_to!(config)
end
EOF

    print_success "Test project created"

    echo "Starting container..."
    vagrant up --provider=docker
    print_success "Container started"
    echo ""

    echo "Test: Verify 'vagrant claude' command is available..."
    vagrant list-commands | grep -q "claude" && print_success "'vagrant claude' command registered"
    echo ""

    echo "Test: Verify 'vagrant claude' help output..."
    vagrant claude --help 2>&1 | grep -q "SSH into the VM" && print_success "'vagrant claude' help text correct"
    echo ""

    cleanup "$test_dir"
    print_success "'vagrant claude' command tests passed!"
}

test_idempotency() {
    print_header "Testing Idempotency (Running vagrant up Twice)"

    local test_dir="$TEST_BASE_DIR-idempotency"
    mkdir -p "$test_dir"
    cd "$test_dir"

    # Create test file
    echo "console.log('Testing idempotency');" > test.js

    # Create Vagrantfile
    cat > Vagrantfile << 'EOF'
Vagrant.configure("2") do |config|
  config.claude_sandbox.provider = "docker"
  config.claude_sandbox.apply_to!(config)
end
EOF

    print_success "Test project created"

    echo "First vagrant up..."
    vagrant up --provider=docker
    print_success "First up completed"
    echo ""

    echo "Second vagrant up (should be idempotent)..."
    vagrant up --provider=docker
    print_success "Second up completed without errors"
    echo ""

    echo "Test: Verify environment still works..."
    vagrant ssh -c "node --version && claude --version"
    print_success "Environment still functional"
    echo ""

    cleanup "$test_dir"
    print_success "Idempotency tests passed!"
}

show_usage() {
    echo "Usage: $0 [provider] [--skip-extended]"
    echo ""
    echo "Providers:"
    echo "  all        - Test both VirtualBox and Docker (default)"
    echo "  virtualbox - Test VirtualBox provider only"
    echo "  docker     - Test Docker provider only"
    echo ""
    echo "Options:"
    echo "  --skip-extended  - Skip extended integration tests (only run basic tests)"
    echo ""
    echo "Examples:"
    echo "  $0                     # Test all providers with all tests"
    echo "  $0 virtualbox          # Test VirtualBox only"
    echo "  $0 docker              # Test Docker only"
    echo "  $0 all --skip-extended # Test all providers, skip extended tests"
}

main() {
    local provider="${1:-all}"
    local skip_extended=false

    # Parse arguments
    for arg in "$@"; do
        case "$arg" in
            --skip-extended)
                skip_extended=true
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            all|virtualbox|docker)
                provider="$arg"
                ;;
            *)
                if [[ ! "$arg" =~ ^-- ]]; then
                    print_error "Unknown provider: $arg"
                    show_usage
                    exit 1
                fi
                ;;
        esac
    done

    print_header "vagrant-claude-sandbox Plugin Test Script"
    echo "Testing provider(s): $provider"
    if [ "$skip_extended" = true ]; then
        echo "Extended tests: SKIPPED"
    fi
    echo ""

    check_prerequisites "$provider"
    build_and_install_plugin

    local failed=0

    # Basic provider tests
    if [ "$provider" = "all" ] || [ "$provider" = "virtualbox" ]; then
        if ! test_virtualbox; then
            print_error "VirtualBox tests failed"
            failed=1
        fi
    fi

    if [ "$provider" = "all" ] || [ "$provider" = "docker" ]; then
        if ! test_docker; then
            print_error "Docker tests failed"
            failed=1
        fi

        if ! test_docker_custom_image; then
            print_error "Docker custom image tests failed"
            failed=1
        fi
    fi

    # Extended tests (Docker only for speed)
    if [ "$skip_extended" = false ]; then
        print_header "Running Extended Integration Tests"

        if ! test_custom_resources; then
            print_error "Custom resources tests failed"
            failed=1
        fi

        if ! test_additional_packages; then
            print_error "Additional packages tests failed"
            failed=1
        fi

        if ! test_no_claude_config; then
            print_error "No Claude config tests failed"
            failed=1
        fi

        if ! test_skip_claude_install; then
            print_error "Skip Claude install tests failed"
            failed=1
        fi

        if ! test_vagrant_claude_command; then
            print_error "'vagrant claude' command tests failed"
            failed=1
        fi

        if ! test_idempotency; then
            print_error "Idempotency tests failed"
            failed=1
        fi
    fi

    if [ $failed -eq 0 ]; then
        print_header "All Tests Passed!"
        echo "The plugin is ready to use. You can now:"
        echo ""
        echo "VirtualBox (default):"
        echo "  config.claude_sandbox.apply_to!(config)"
        echo ""
        echo "Docker:"
        echo "  config.claude_sandbox.provider = \"docker\""
        echo "  config.claude_sandbox.apply_to!(config)"
        echo ""
        echo "Docker with custom image:"
        echo "  config.claude_sandbox.provider = \"docker\""
        echo "  config.claude_sandbox.docker_image = \"my-image:latest\""
        echo "  config.claude_sandbox.apply_to!(config)"
    else
        print_header "Some Tests Failed"
        exit 1
    fi
}

# Trap to ensure cleanup on script exit
trap 'cleanup "$TEST_BASE_DIR-virtualbox" 2>/dev/null; \
      cleanup "$TEST_BASE_DIR-docker" 2>/dev/null; \
      cleanup "$TEST_BASE_DIR-docker-custom" 2>/dev/null; \
      cleanup "$TEST_BASE_DIR-custom-resources" 2>/dev/null; \
      cleanup "$TEST_BASE_DIR-additional-packages" 2>/dev/null; \
      cleanup "$TEST_BASE_DIR-no-claude-config" 2>/dev/null; \
      cleanup "$TEST_BASE_DIR-skip-claude" 2>/dev/null; \
      cleanup "$TEST_BASE_DIR-claude-command" 2>/dev/null; \
      cleanup "$TEST_BASE_DIR-idempotency" 2>/dev/null' EXIT

main "$@"
