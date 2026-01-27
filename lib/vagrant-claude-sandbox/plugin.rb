require_relative "path_fixer"
require 'fileutils'

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

      # Check for required plugins on environment load
      action_hook(:check_dependencies, :environment_load) do |hook|
        hook.after(Vagrant::Action::Builtin::HandleBox, Action::CheckDependencies)
      end
    end

    # Action to check for vagrant-notify-forwarder plugin
    module Action
      class CheckDependencies
        def initialize(app, env)
          @app = app
        end

        def call(env)
          # Check if vagrant-notify-forwarder is installed
          unless plugin_installed?("vagrant-notify-forwarder")
            env[:ui].warn("vagrant-notify-forwarder plugin is not installed.")
            env[:ui].warn("This plugin enables real-time filesystem change notifications from host to guest,")
            env[:ui].warn("improving performance for development tools like webpack, nodemon, etc.")
            env[:ui].warn("")
            env[:ui].info("Install it with: vagrant plugin install vagrant-notify-forwarder")
            env[:ui].warn("")
          end

          @app.call(env)
        end

        private

        def plugin_installed?(plugin_name)
          Vagrant::Plugin::Manager.instance.installed_plugins.key?(plugin_name)
        end
      end
    end
  end
end
