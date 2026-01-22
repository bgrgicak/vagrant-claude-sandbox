# Vagrant Claude Sandbox

A Vagrant plugin for running Claude Code in an isolated VM sandbox.

## Features

- Ubuntu 24.04 LTS with Docker, Node.js, git pre-installed
- Automatic Claude Code CLI installation
- Synced workspace folder and Claude config
- **Full Claude plugins and skills support** - automatically loads your installed plugins and skills with fixed paths
- `claude-yolo` wrapper (runs Claude with `--dangerously-skip-permissions`)
- Customizable VM resources

## Prerequisites

- [Vagrant](https://www.vagrantup.com/downloads) >= 2.2.0
- [VirtualBox](https://www.virtualbox.org/wiki/Downloads) >= 6.1

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

## Plugin and Skills Support

This plugin automatically copies your `~/.claude/` directory to the VM and fixes absolute paths in plugin configuration files. This means:

- All your installed Claude plugins will work in the VM
- All your custom skills will be available
- Plugin paths are automatically updated from host paths to VM paths

The plugin configuration files that are updated:
- `~/.claude/plugins/installed_plugins.json`
- `~/.claude/plugins/known_marketplaces.json`

This ensures that plugins and skills that reference local file paths will work correctly inside the VM environment.

## Credits

Original idea by [@emilburzo](https://github.com/emilburzo) - [blog post](https://blog.emilburzo.com/2026/01/running-claude-code-dangerously-safely/)

## License

MIT License - see [LICENSE](LICENSE)
