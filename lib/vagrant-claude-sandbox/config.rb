module VagrantPlugins
  module ClaudeSandbox
    class Config < Vagrant.plugin("2", :config)
      attr_accessor :memory
      attr_accessor :cpus
      attr_accessor :box
      attr_accessor :workspace_path
      attr_accessor :claude_config_path
      attr_accessor :skip_claude_cli_install
      attr_accessor :additional_packages

      def initialize
        @memory = UNSET_VALUE
        @cpus = UNSET_VALUE
        @box = UNSET_VALUE
        @workspace_path = UNSET_VALUE
        @claude_config_path = UNSET_VALUE
        @skip_claude_cli_install = UNSET_VALUE
        @additional_packages = UNSET_VALUE
      end

      def finalize!
        @memory = 4096 if @memory == UNSET_VALUE
        @cpus = 2 if @cpus == UNSET_VALUE
        @box = "bento/ubuntu-24.04" if @box == UNSET_VALUE
        @workspace_path = "/agent-workspace" if @workspace_path == UNSET_VALUE
        @claude_config_path = File.expand_path("~/.claude/") if @claude_config_path == UNSET_VALUE
        @skip_claude_cli_install = false if @skip_claude_cli_install == UNSET_VALUE
        @additional_packages = [] if @additional_packages == UNSET_VALUE
      end

      def validate(machine)
        errors = _detected_errors

        if @memory && !@memory.is_a?(Integer)
          errors << "memory must be an integer"
        end

        if @cpus && !@cpus.is_a?(Integer)
          errors << "cpus must be an integer"
        end

        if @additional_packages && !@additional_packages.is_a?(Array)
          errors << "additional_packages must be an array"
        end

        { "Claude Sandbox" => errors }
      end

      # Apply all Claude Sandbox configuration to the Vagrant config
      def apply_to!(root_config)
        # Ensure values are finalized before use
        finalize!

        # Set the box
        root_config.vm.box = @box

        # Configure synced folder for workspace
        root_config.vm.synced_folder ".", @workspace_path,
          create: true,
          owner: "vagrant",
          group: "vagrant"

        # Copy Claude config if it exists
        if File.directory?(@claude_config_path)
          root_config.vm.synced_folder @claude_config_path, "/home/vagrant/.claude",
            create: true,
            owner: "vagrant",
            group: "vagrant"
        end

        # Configure provider (VirtualBox)
        root_config.vm.provider "virtualbox" do |vb|
          vb.memory = @memory
          vb.cpus = @cpus
          vb.customize ["modifyvm", :id, "--audio", "none"]
          vb.customize ["modifyvm", :id, "--usb", "off"]
        end

        # Provision the VM
        unless @skip_claude_cli_install
          root_config.vm.provision "shell", inline: generate_provision_script
        end

        # Configure SSH to auto-cd to workspace
        root_config.ssh.extra_args = ["-t", "cd #{@workspace_path}; bash --login"]
      end

      private

      def generate_provision_script
        additional_packages = @additional_packages.join(" ")

        script = <<-SHELL
          set -e

          echo "Updating package lists..."
          apt-get update

          echo "Installing base packages..."
          apt-get install -y \
            apt-transport-https \
            ca-certificates \
            curl \
            gnupg \
            lsb-release \
            git \
            unzip \
            #{additional_packages}

          # Install Docker
          if ! command -v docker &> /dev/null; then
            echo "Installing Docker..."
            curl -fsSL https://get.docker.com -o get-docker.sh
            sh get-docker.sh
            usermod -aG docker vagrant
            rm get-docker.sh
          else
            echo "Docker already installed"
          fi

          # Install Node.js and npm
          if ! command -v node &> /dev/null; then
            echo "Installing Node.js..."
            curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
            apt-get install -y nodejs
          else
            echo "Node.js already installed"
          fi

          # Install Claude Code CLI
          if ! command -v claude &> /dev/null; then
            echo "Installing Claude Code CLI..."
            npm install -g @anthropic-ai/claude-code --no-audit
          else
            echo "Claude Code CLI already installed"
          fi

          # Create claude-yolo wrapper
          echo "Creating claude-yolo command..."
          cat > /usr/local/bin/claude-yolo << 'EOF'
#!/bin/bash
claude --dangerously-skip-permissions "$@"
EOF
          chmod +x /usr/local/bin/claude-yolo

          echo "Claude sandbox environment setup complete!"
          echo "You can now run 'claude-yolo' to start Claude Code with permissions disabled"
        SHELL

        script
      end
    end
  end
end
