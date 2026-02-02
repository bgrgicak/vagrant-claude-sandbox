require 'spec_helper'

describe VagrantPlugins::ClaudeSandbox::Config do
  let(:machine) { double("machine") }
  subject { described_class.new }

  describe "defaults" do
    before { subject.finalize! }

    it "sets default memory to 4096" do
      expect(subject.memory).to eq(4096)
    end

    it "sets default cpus to 2" do
      expect(subject.cpus).to eq(2)
    end

    it "sets default box to bento/ubuntu-24.04" do
      expect(subject.box).to eq("bento/ubuntu-24.04")
    end

    it "sets default workspace_path to /agent-workspace" do
      expect(subject.workspace_path).to eq("/agent-workspace")
    end

    it "sets default claude_config_path to ~/.claude/" do
      expect(subject.claude_config_path).to eq(File.expand_path("~/.claude/"))
    end

    it "sets default skip_claude_cli_install to false" do
      expect(subject.skip_claude_cli_install).to eq(false)
    end

    it "sets default additional_packages to empty array" do
      expect(subject.additional_packages).to eq([])
    end

    it "sets default provider to docker" do
      expect(subject.provider).to eq("docker")
    end

    it "sets default docker_image to nil" do
      expect(subject.docker_image).to be_nil
    end

    it "sets default ubuntu_mirror to nil" do
      expect(subject.ubuntu_mirror).to be_nil
    end
  end

  describe "custom values" do
    it "allows setting custom memory" do
      subject.memory = 8192
      subject.finalize!
      expect(subject.memory).to eq(8192)
    end

    it "allows setting custom cpus" do
      subject.cpus = 4
      subject.finalize!
      expect(subject.cpus).to eq(4)
    end

    it "allows setting custom workspace_path" do
      subject.workspace_path = "/custom-workspace"
      subject.finalize!
      expect(subject.workspace_path).to eq("/custom-workspace")
    end

    it "allows setting custom provider to virtualbox" do
      subject.provider = "virtualbox"
      subject.finalize!
      expect(subject.provider).to eq("virtualbox")
    end

    it "allows setting custom docker_image" do
      subject.docker_image = "my-image:latest"
      subject.finalize!
      expect(subject.docker_image).to eq("my-image:latest")
    end

    it "allows setting custom ubuntu_mirror" do
      subject.ubuntu_mirror = "http://mirror.example.com/ubuntu"
      subject.finalize!
      expect(subject.ubuntu_mirror).to eq("http://mirror.example.com/ubuntu")
    end

    it "allows setting additional_packages" do
      subject.additional_packages = ["vim", "htop"]
      subject.finalize!
      expect(subject.additional_packages).to eq(["vim", "htop"])
    end

    it "allows setting skip_claude_cli_install to true" do
      subject.skip_claude_cli_install = true
      subject.finalize!
      expect(subject.skip_claude_cli_install).to eq(true)
    end
  end

  describe "validation" do
    before { subject.finalize! }

    context "with valid configuration" do
      it "returns no errors" do
        result = subject.validate(machine)
        expect(result["Claude Sandbox"]).to be_empty
      end
    end

    context "with invalid memory type" do
      it "returns an error for string memory" do
        subject.memory = "4096"
        result = subject.validate(machine)
        expect(result["Claude Sandbox"]).to include("memory must be an integer")
      end

      it "returns an error for float memory" do
        subject.memory = 4096.5
        result = subject.validate(machine)
        expect(result["Claude Sandbox"]).to include("memory must be an integer")
      end
    end

    context "with invalid cpus type" do
      it "returns an error for string cpus" do
        subject.cpus = "2"
        result = subject.validate(machine)
        expect(result["Claude Sandbox"]).to include("cpus must be an integer")
      end

      it "returns an error for float cpus" do
        subject.cpus = 2.5
        result = subject.validate(machine)
        expect(result["Claude Sandbox"]).to include("cpus must be an integer")
      end
    end

    context "with invalid additional_packages type" do
      it "returns an error for string additional_packages" do
        subject.additional_packages = "vim htop"
        result = subject.validate(machine)
        expect(result["Claude Sandbox"]).to include("additional_packages must be an array")
      end

      it "returns an error for hash additional_packages" do
        subject.additional_packages = { vim: true }
        result = subject.validate(machine)
        expect(result["Claude Sandbox"]).to include("additional_packages must be an array")
      end
    end

    context "with invalid provider" do
      it "returns an error for unsupported provider" do
        subject.provider = "vmware"
        result = subject.validate(machine)
        expect(result["Claude Sandbox"]).to include("provider must be 'virtualbox' or 'docker'")
      end

      it "returns an error for invalid provider string" do
        subject.provider = "invalid"
        result = subject.validate(machine)
        expect(result["Claude Sandbox"]).to include("provider must be 'virtualbox' or 'docker'")
      end
    end

    context "with multiple validation errors" do
      it "returns all errors" do
        subject.memory = "invalid"
        subject.cpus = "invalid"
        subject.provider = "invalid"
        result = subject.validate(machine)
        errors = result["Claude Sandbox"]
        expect(errors).to include("memory must be an integer")
        expect(errors).to include("cpus must be an integer")
        expect(errors).to include("provider must be 'virtualbox' or 'docker'")
      end
    end
  end

  describe "#generate_provision_script" do
    before { subject.finalize! }

    it "includes Docker installation for virtualbox provider" do
      subject.provider = "virtualbox"
      script = subject.send(:generate_provision_script)
      expect(script).to include("Install Docker")
      expect(script).to include("curl -fsSL https://get.docker.com")
    end

    it "skips Docker installation for docker provider" do
      subject.provider = "docker"
      script = subject.send(:generate_provision_script)
      expect(script).not_to include("Install Docker")
      expect(script).not_to include("curl -fsSL https://get.docker.com")
    end

    it "includes additional packages when specified" do
      subject.additional_packages = ["vim", "htop", "tmux"]
      script = subject.send(:generate_provision_script)
      expect(script).to include("vim htop tmux")
    end

    it "includes ubuntu mirror configuration when specified" do
      subject.ubuntu_mirror = "http://mirror.example.com/ubuntu-ports"
      script = subject.send(:generate_provision_script)
      expect(script).to include("Configuring Ubuntu mirror")
      expect(script).to include("http://mirror.example.com/ubuntu-ports")
    end

    it "skips ubuntu mirror configuration when not specified" do
      subject.ubuntu_mirror = nil
      script = subject.send(:generate_provision_script)
      expect(script).not_to include("Configuring Ubuntu mirror")
    end

    it "includes nvm installation" do
      script = subject.send(:generate_provision_script)
      expect(script).to include("Installing nvm")
      expect(script).to include("nvm-sh/nvm")
    end

    it "includes Claude CLI installation" do
      script = subject.send(:generate_provision_script)
      expect(script).to include("Installing Claude Code CLI")
      expect(script).to include("@anthropic-ai/claude-code")
    end

    it "includes plugin path fixing logic" do
      script = subject.send(:generate_provision_script)
      expect(script).to include("Fix absolute paths in plugin configuration")
      expect(script).to include("installed_plugins.json")
      expect(script).to include("known_marketplaces.json")
    end
  end

  describe "#apply_to!" do
    let(:root_config) { double("root_config") }
    let(:vm_config) { double("vm_config") }
    let(:vb_provider) { double("virtualbox_provider") }
    let(:docker_provider) { double("docker_provider") }
    let(:trigger_config) { double("trigger_config") }
    let(:trigger) { double("trigger") }

    before do
      allow(root_config).to receive(:vm).and_return(vm_config)
      allow(vm_config).to receive(:synced_folder)
      allow(vm_config).to receive(:provision)
      allow(vm_config).to receive(:network)
      allow(vm_config).to receive(:provider).and_yield(vb_provider, root_config)
      allow(vm_config).to receive(:provider).with("docker").and_yield(docker_provider)
      allow(root_config).to receive(:vm).and_return(vm_config)
      allow(vm_config).to receive(:box=)
      allow(vb_provider).to receive(:memory=)
      allow(vb_provider).to receive(:cpus=)
      allow(vb_provider).to receive(:customize)
      allow(docker_provider).to receive(:image=)
      allow(docker_provider).to receive(:build_dir=)
      allow(docker_provider).to receive(:has_ssh=)
      allow(docker_provider).to receive(:remains_running=)
      allow(docker_provider).to receive(:create_args=)
      allow(File).to receive(:directory?).and_return(false)

      # Mock trigger configuration
      allow(root_config).to receive(:trigger).and_return(trigger_config)
      allow(trigger_config).to receive(:after).and_yield(trigger)
      allow(trigger).to receive(:ruby)
    end

    it "configures synced folder for workspace" do
      expect(vm_config).to receive(:synced_folder).with(
        ".",
        "/agent-workspace",
        hash_including(create: true, owner: "vagrant", group: "vagrant")
      )
      subject.apply_to!(root_config)
    end

    it "configures SSH port forwarding with auto-correction" do
      expect(vm_config).to receive(:network).with(
        :forwarded_port,
        hash_including(guest: 22, host: 2200, id: "ssh", auto_correct: true)
      )
      subject.apply_to!(root_config)
    end

    context "when Claude config directory exists" do
      it "provisions Claude config directory" do
        # Mock File.directory? to return true for the actual claude_config_path value
        subject.finalize!  # This sets the path to File.expand_path("~/.claude/")
        allow(File).to receive(:directory?).and_call_original
        allow(File).to receive(:directory?).with(subject.claude_config_path).and_return(true)

        provision_calls = []
        allow(vm_config).to receive(:provision) do |*args|
          provision_calls << args
        end

        subject.apply_to!(root_config)

        file_provision_call = provision_calls.find { |args| args[0] == "file" }
        expect(file_provision_call).not_to be_nil
        expect(file_provision_call[1][:source]).to eq(subject.claude_config_path)
        expect(file_provision_call[1][:destination]).to eq("/tmp/claude-config")
      end
    end

    context "when Claude config directory does not exist" do
      before do
        allow(File).to receive(:directory?).with(subject.claude_config_path).and_return(false)
      end

      it "does not provision Claude config directory" do
        expect(vm_config).not_to receive(:provision).with(
          "file",
          hash_including(destination: "/tmp/claude-config")
        )
        subject.apply_to!(root_config)
      end
    end

    it "configures VirtualBox provider with correct memory and cpus" do
      subject.memory = 8192
      subject.cpus = 4
      expect(vb_provider).to receive(:memory=).with(8192)
      expect(vb_provider).to receive(:cpus=).with(4)
      subject.apply_to!(root_config)
    end

    it "configures Docker provider with custom image when specified" do
      subject.docker_image = "custom:latest"
      expect(docker_provider).to receive(:image=).with("custom:latest")
      expect(docker_provider).not_to receive(:build_dir=)
      subject.apply_to!(root_config)
    end

    it "configures Docker provider to build from Dockerfile when no custom image" do
      subject.docker_image = nil
      expect(docker_provider).not_to receive(:image=)
      expect(docker_provider).to receive(:build_dir=)
      subject.apply_to!(root_config)
    end
  end
end
