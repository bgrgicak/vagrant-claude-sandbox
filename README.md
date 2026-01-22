# Vagrant Claude Sandbox

A Vagrant plugin for running Claude Code in an isolated VM sandbox.

## Features

- Ubuntu 24.04 LTS with Docker, Node.js, git pre-installed
- Automatic Claude Code CLI installation
- Synced workspace folder and Claude config
- `claude-yolo` wrapper (runs Claude with `--dangerously-skip-permissions`)
- Customizable VM resources

## Prerequisites

- [Vagrant](https://www.vagrantup.com/downloads) >= 2.2.0
- [VirtualBox](https://www.virtualbox.org/wiki/Downloads) >= 6.1

## Installation

```bash
vagrant plugin install vagrant-claude-sandbox
```

Or from source:

```bash
gem build vagrant-claude-sandbox.gemspec
vagrant plugin install vagrant-claude-sandbox-*.gem
```

## Usage

Create a `Vagrantfile`:

```ruby
Vagrant.configure("2") do |config|
  config.claude_sandbox.apply_to!(config)
end
```

Start the VM:

```bash
vagrant up
vagrant ssh
claude-yolo  # Inside VM
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

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `memory` | `4096` | RAM in MB |
| `cpus` | `2` | Number of CPUs |
| `box` | `"bento/ubuntu-24.04"` | Vagrant box |
| `workspace_path` | `"/agent-workspace"` | Workspace path in VM |
| `claude_config_path` | `"~/.claude/"` | Host Claude config path |
| `skip_claude_cli_install` | `false` | Skip Claude CLI installation |
| `additional_packages` | `[]` | Extra apt packages |

## Troubleshooting

**Plugin not loading**: Run `vagrant plugin list`
**Provisioning fails**: Check `VBoxManage --version`
**Config not syncing**: Ensure `~/.claude/` exists
**Permission issues**: Run `vagrant destroy && vagrant up`

## Security

The VM provides isolation, but note:
- `claude-yolo` disables permission checks
- Synced folders can still affect host files
- Network access is enabled by default

## Credits

Original idea by [@emilburzo](https://github.com/emilburzo) - [blog post](https://blog.emilburzo.com/2026/01/running-claude-code-dangerously-safely/)

## License

MIT License - see [LICENSE](LICENSE)
