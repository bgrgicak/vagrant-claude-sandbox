# Vagrant Claude Sandbox

A Vagrant plugin for running Claude Code in an isolated sandbox environment.

## Features

- Fast container-based sandbox using Docker
- Ubuntu 24.04 LTS with Node.js and git pre-installed
- Automatic Claude Code CLI installation
- Synced workspace folder and Claude config (plugins and skills work automatically)
- Customizable resources (memory, CPUs)
- Optional VirtualBox provider for full VM isolation

## Prerequisites

- [Vagrant](https://www.vagrantup.com/downloads) >= 2.2.0
- [Docker](https://docs.docker.com/get-docker/) (default provider)

## Installation

```bash
vagrant plugin install vagrant-claude-sandbox
```

## Usage

Create a `Vagrantfile`:

```ruby
Vagrant.configure("2") do |config|
  config.claude_sandbox.apply_to!(config)
end
```

Start the sandbox:

```bash
vagrant up
vagrant claude  # Launch Claude CLI with Chrome integration
```

Access a normal shell:

```bash
vagrant ssh  # Regular shell session
```

### Custom Configuration

```ruby
Vagrant.configure("2") do |config|
  config.claude_sandbox.apply_to!(config) do |sandbox|
    sandbox.memory = 8192
    sandbox.cpus = 4
    sandbox.additional_packages = ["vim", "htop"]
  end
end
```

### Mounting Additional Directories

Mount additional directories using Vagrant's `synced_folder` directive:

```ruby
Vagrant.configure("2") do |config|
  config.claude_sandbox.apply_to!(config) do |sandbox|
    sandbox.memory = 8192
    sandbox.cpus = 4
  end

  config.vm.synced_folder "~/Projects/my-project", "/my-project"
end
```

**Note:** The workspace (`/agent-workspace`) and Claude config (`~/.claude/`) are mounted automatically.

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `provider` | `"docker"` | Provider: `"docker"` or `"virtualbox"` |
| `memory` | `4096` | RAM in MB |
| `cpus` | `2` | Number of CPUs |
| `workspace_path` | `"/agent-workspace"` | Workspace path in container/VM |
| `claude_config_path` | `"~/.claude/"` | Host Claude config path |
| `additional_packages` | `[]` | Extra apt packages |
| `skip_claude_cli_install` | `false` | Skip Claude CLI installation |
| `ubuntu_mirror` | `nil` | Ubuntu package mirror URL (uses official mirror by default) |

## VirtualBox Provider

For full VM isolation or Docker-in-Docker capabilities:

```ruby
Vagrant.configure("2") do |config|
  config.claude_sandbox.provider = "virtualbox"
  config.claude_sandbox.apply_to!(config)
end
```

**When to use VirtualBox:**
- You need Docker available inside the sandbox
- You need full VM isolation (kernel-level)
- You're running on a system without Docker

**Prerequisites:**
- [VirtualBox](https://www.virtualbox.org/wiki/Downloads) >= 6.1

### Ubuntu Mirror Configuration

By default, the plugin uses Ubuntu's official mirror (`http://ports.ubuntu.com/ubuntu-ports`). If package updates are slow in your region, you can configure a faster mirror:

```ruby
Vagrant.configure("2") do |config|
  # Choose a mirror close to your location for faster updates
  config.claude_sandbox.ubuntu_mirror = "http://ftp.jaist.ac.jp/pub/Linux/ubuntu-ports"  # Japan
  config.claude_sandbox.apply_to!(config)
end
```

**Trusted mirrors for ARM (ubuntu-ports):**
- Official Ubuntu: `http://ports.ubuntu.com/ubuntu-ports` (default, safest)
- JAIST (Japan): `http://ftp.jaist.ac.jp/pub/Linux/ubuntu-ports` (university mirror)
- Kakao (Korea): `http://mirror.kakao.com/ubuntu-ports` (major tech company)

**Security note:** Only use mirrors from trusted sources. The official Ubuntu mirror is always the safest option.

## Development and Testing

### Running Tests

The project includes comprehensive unit and integration tests:

```bash
# Install development dependencies
bundle install

# Run unit tests
bundle exec rake spec

# Run integration tests
./test-plugin.sh docker --skip-extended  # Quick test

# Run all tests
bundle exec rake test
```

See [TESTING.md](TESTING.md) for detailed testing instructions.

### Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for your changes
4. Ensure all tests pass: `bundle exec rake test`
5. Submit a pull request

## Troubleshooting

### Docker "Permission denied" Error

**This is now handled automatically by the plugin!**

The plugin automatically detects and fixes PATH conflicts that could cause "Permission denied" errors with the Docker provider. If you have a directory named `docker` in your PATH before the actual Docker executable, the plugin will reorder your PATH to prioritize common Docker binary locations.

You should see a message during `vagrant up` if a conflict was detected and fixed:
```
Detected Docker PATH conflict - automatically reordered PATH
```

If you're still experiencing issues, you can manually fix the PATH as a fallback:
```bash
PATH=/usr/local/bin:$PATH vagrant up
```

## Credits

Original idea by [@emilburzo](https://github.com/emilburzo) - [blog post](https://blog.emilburzo.com/2026/01/running-claude-code-dangerously-safely/)

## License

MIT License - see [LICENSE](LICENSE)
