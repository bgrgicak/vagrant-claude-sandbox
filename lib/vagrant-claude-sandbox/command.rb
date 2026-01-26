module VagrantPlugins
  module ClaudeSandbox
    class Command < Vagrant.plugin("2", :command)
      def self.synopsis
        "SSH into the VM and launch Claude CLI"
      end

      def execute
        options = {}
        opts = OptionParser.new do |o|
          o.banner = "Usage: vagrant claude [-- extra ssh args]"
          o.separator ""
          o.separator self.class.synopsis
          o.separator ""
          o.separator "This will SSH into the VM, cd to the workspace, and launch Claude CLI"
          o.separator "with Chrome integration enabled."
        end

        # Parse the options
        argv = parse_options(opts)
        return if !argv

        # Get the machine
        with_target_vms(argv, single_target: true) do |machine|
          # Get workspace path from config
          config = machine.config.claude_sandbox
          workspace_path = config.workspace_path || "/agent-workspace"

          # Build the command to run
          # Source nvm only if needed (claude might already be in PATH)
          command = "cd #{workspace_path}; [ -f ~/.nvm/nvm.sh ] && . ~/.nvm/nvm.sh; exec claude --dangerously-skip-permissions --chrome"

          # Execute SSH with the command
          machine.action(:ssh_run, ssh_run_command: command, ssh_opts: { extra_args: ["-t"] })
        end

        # Success
        0
      end
    end
  end
end
