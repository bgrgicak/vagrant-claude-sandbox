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
      attr_accessor :provider          # "virtualbox" or "docker"
      attr_accessor :docker_image      # Docker image (default: build from Dockerfile)
      attr_accessor :ubuntu_mirror     # Ubuntu mirror URL (default: nil, uses official mirror)

      def initialize
        @memory = UNSET_VALUE
        @cpus = UNSET_VALUE
        @box = UNSET_VALUE
        @workspace_path = UNSET_VALUE
        @claude_config_path = UNSET_VALUE
        @skip_claude_cli_install = UNSET_VALUE
        @additional_packages = UNSET_VALUE
        @provider = UNSET_VALUE
        @docker_image = UNSET_VALUE
        @ubuntu_mirror = UNSET_VALUE
      end

      def finalize!
        @memory = 4096 if @memory == UNSET_VALUE
        @cpus = 2 if @cpus == UNSET_VALUE
        @box = "bento/ubuntu-24.04" if @box == UNSET_VALUE
        @workspace_path = "/agent-workspace" if @workspace_path == UNSET_VALUE
        @claude_config_path = File.expand_path("~/.claude/") if @claude_config_path == UNSET_VALUE
        @skip_claude_cli_install = false if @skip_claude_cli_install == UNSET_VALUE
        @additional_packages = [] if @additional_packages == UNSET_VALUE
        @provider = "virtualbox" if @provider == UNSET_VALUE
        @docker_image = nil if @docker_image == UNSET_VALUE
        @ubuntu_mirror = nil if @ubuntu_mirror == UNSET_VALUE
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

        if @provider != UNSET_VALUE && !["virtualbox", "docker"].include?(@provider)
          errors << "provider must be 'virtualbox' or 'docker'"
        end

        { "Claude Sandbox" => errors }
      end

      # Apply all Claude Sandbox configuration to the Vagrant config
      def apply_to!(root_config)
        # Ensure values are finalized before use
        finalize!

        # Common configuration
        apply_common_config!(root_config)

        # Always configure both providers
        # Vagrant will choose the appropriate one based on:
        # 1. --provider flag from command line
        # 2. Existing .vagrant directory state
        # 3. Default provider (VirtualBox)
        apply_virtualbox_config!(root_config)
        apply_docker_config!(root_config)

        # Provisioning (with provider awareness)
        apply_provisioning!(root_config)
      end

      private

      def apply_common_config!(root_config)
        # Configure synced folder for workspace
        root_config.vm.synced_folder ".", @workspace_path,
          create: true,
          owner: "vagrant",
          group: "vagrant"

        # Copy Claude config if it exists (using file provisioner to fix plugin paths)
        if File.directory?(@claude_config_path)
          root_config.vm.provision "file",
            source: @claude_config_path,
            destination: "/tmp/claude-config"
        end

        # Configure SSH port with auto-correction for conflicts
        root_config.vm.network :forwarded_port, guest: 22, host: 2200, id: "ssh", auto_correct: true
      end

      def apply_virtualbox_config!(root_config)
        root_config.vm.provider "virtualbox" do |vb, override|
          # Set box only for VirtualBox provider
          override.vm.box = @box
          vb.memory = @memory
          vb.cpus = @cpus
          vb.customize ["modifyvm", :id, "--audio", "none"]
          vb.customize ["modifyvm", :id, "--usb", "off"]
        end
      end

      def apply_docker_config!(root_config)
        root_config.vm.provider "docker" do |d|
          if @docker_image
            d.image = @docker_image
          else
            d.build_dir = File.expand_path("../../docker", __FILE__)
          end
          d.has_ssh = true
          d.remains_running = true
          d.create_args = ["--memory=#{@memory}m", "--cpus=#{@cpus}"]
        end
      end

      def apply_provisioning!(root_config)
        unless @skip_claude_cli_install
          root_config.vm.provision "shell",
            inline: generate_provision_script,
            env: {"HOST_CLAUDE_PATH" => @claude_config_path}
        end
      end

      def generate_provision_script
        additional_packages = @additional_packages.join(" ")
        skip_docker = @provider == "docker"

        docker_install_script = skip_docker ? "" : <<-DOCKER
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
        DOCKER

        mirror_config = @ubuntu_mirror ? <<-MIRROR
          # Switch to faster Ubuntu mirror
          echo "Configuring Ubuntu mirror: #{@ubuntu_mirror}"
          sed -i 's|http://ports.ubuntu.com/ubuntu-ports|#{@ubuntu_mirror}|g' /etc/apt/sources.list.d/ubuntu.sources 2>/dev/null || true
          sed -i 's|http://ports.ubuntu.com/ubuntu-ports|#{@ubuntu_mirror}|g' /etc/apt/sources.list 2>/dev/null || true
        MIRROR
        : ""

        script = <<-SHELL
          set -e
#{mirror_config}
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

          #{docker_install_script}

          # Install nvm for the vagrant user
          if [ ! -d "/home/vagrant/.nvm" ]; then
            echo "Installing nvm..."
            # Install nvm as vagrant user
            sudo -u vagrant bash -c 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash'

            # Load nvm in this script
            export NVM_DIR="/home/vagrant/.nvm"
            [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

            # Install Node.js LTS version
            echo "Installing Node.js LTS via nvm..."
            sudo -u vagrant bash -c '. /home/vagrant/.nvm/nvm.sh && nvm install --lts && nvm use --lts'
          else
            echo "nvm already installed"
          fi

          # Ensure nvm is loaded for subsequent commands
          export NVM_DIR="/home/vagrant/.nvm"
          [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

          # Install Claude Code CLI
          if ! sudo -u vagrant bash -c '. /home/vagrant/.nvm/nvm.sh && command -v claude' &> /dev/null; then
            echo "Installing Claude Code CLI..."
            sudo -u vagrant bash -c '. /home/vagrant/.nvm/nvm.sh && npm install -g @anthropic-ai/claude-code --no-audit'
          else
            echo "Claude Code CLI already installed"
          fi

          # Move Claude configuration from /tmp and fix plugin paths
          if [ -d "/tmp/claude-config" ]; then
            echo "Setting up Claude configuration with plugins and skills..."
            rm -rf /home/vagrant/.claude
            mv /tmp/claude-config /home/vagrant/.claude

            # Fix absolute paths in plugin configuration files to point to VM paths
            if [ -f "/home/vagrant/.claude/plugins/installed_plugins.json" ]; then
              sed -i "s|${HOST_CLAUDE_PATH}|/home/vagrant/.claude|g" /home/vagrant/.claude/plugins/installed_plugins.json
            fi
            if [ -f "/home/vagrant/.claude/plugins/known_marketplaces.json" ]; then
              sed -i "s|${HOST_CLAUDE_PATH}|/home/vagrant/.claude|g" /home/vagrant/.claude/plugins/known_marketplaces.json
            fi

            chown -R vagrant:vagrant /home/vagrant/.claude
            echo "Claude plugins and skills loaded successfully!"
          fi

          echo "Claude sandbox environment setup complete!"
        SHELL

        script
      end
    end
  end
end
