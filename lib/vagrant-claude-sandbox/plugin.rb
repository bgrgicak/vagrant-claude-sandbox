require_relative "path_fixer"

# Fix Docker PATH issues immediately when plugin loads (before Vagrant initialization)
VagrantPlugins::ClaudeSandbox::PathFixer.fix_docker_path!

module VagrantPlugins
  module ClaudeSandbox
    class Plugin < Vagrant.plugin("2")
      name "Claude Sandbox"
      description "Provides a pre-configured sandbox environment for running Claude Code in an isolated VM"

      config "claude_sandbox" do
        require_relative "config"
        Config
      end

      command "claude" do
        require_relative "command"
        Command
      end
    end
  end
end
