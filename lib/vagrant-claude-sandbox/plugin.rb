module VagrantPlugins
  module ClaudeSandbox
    class Plugin < Vagrant.plugin("2")
      name "Claude Sandbox"
      description "Provides a pre-configured sandbox environment for running Claude Code in an isolated VM"

      config "claude_sandbox" do
        require_relative "config"
        Config
      end
    end
  end
end
