require 'spec_helper'

describe VagrantPlugins::ClaudeSandbox::Command do
  let(:env) { double("env") }
  let(:machine) { double("machine") }
  let(:config) { double("config") }
  let(:claude_config) { double("claude_config") }

  subject { described_class.new([], env) }

  before do
    allow(subject).to receive(:with_target_vms).and_yield(machine)
    allow(machine).to receive(:config).and_return(config)
    allow(config).to receive(:claude_sandbox).and_return(claude_config)
    allow(machine).to receive(:action)
  end

  describe ".synopsis" do
    it "returns a description" do
      expect(described_class.synopsis).to eq("SSH into the VM and launch Claude CLI")
    end
  end

  describe "#execute" do
    context "with default workspace path" do
      before do
        allow(claude_config).to receive(:workspace_path).and_return("/agent-workspace")
      end

      it "executes SSH with correct command" do
        expect(machine).to receive(:action).with(
          :ssh_run,
          hash_including(
            ssh_run_command: "cd /agent-workspace; [ -f ~/.nvm/nvm.sh ] && . ~/.nvm/nvm.sh; exec claude --dangerously-skip-permissions --chrome",
            ssh_opts: { extra_args: ["-t"] }
          )
        )

        result = subject.execute
        expect(result).to eq(0)
      end
    end

    context "with custom workspace path" do
      before do
        allow(claude_config).to receive(:workspace_path).and_return("/custom-workspace")
      end

      it "executes SSH with custom workspace path" do
        expect(machine).to receive(:action).with(
          :ssh_run,
          hash_including(
            ssh_run_command: "cd /custom-workspace; [ -f ~/.nvm/nvm.sh ] && . ~/.nvm/nvm.sh; exec claude --dangerously-skip-permissions --chrome",
            ssh_opts: { extra_args: ["-t"] }
          )
        )

        result = subject.execute
        expect(result).to eq(0)
      end
    end

    context "when workspace_path is nil" do
      before do
        allow(claude_config).to receive(:workspace_path).and_return(nil)
      end

      it "falls back to default /agent-workspace" do
        expect(machine).to receive(:action).with(
          :ssh_run,
          hash_including(
            ssh_run_command: "cd /agent-workspace; [ -f ~/.nvm/nvm.sh ] && . ~/.nvm/nvm.sh; exec claude --dangerously-skip-permissions --chrome",
            ssh_opts: { extra_args: ["-t"] }
          )
        )

        result = subject.execute
        expect(result).to eq(0)
      end
    end

    it "returns 0 on success" do
      allow(claude_config).to receive(:workspace_path).and_return("/agent-workspace")
      result = subject.execute
      expect(result).to eq(0)
    end

    it "includes nvm initialization in command" do
      allow(claude_config).to receive(:workspace_path).and_return("/agent-workspace")

      expect(machine).to receive(:action) do |action_name, opts|
        command = opts[:ssh_run_command]
        expect(command).to include(". ~/.nvm/nvm.sh")
      end

      subject.execute
    end

    it "includes claude CLI flags" do
      allow(claude_config).to receive(:workspace_path).and_return("/agent-workspace")

      expect(machine).to receive(:action) do |action_name, opts|
        command = opts[:ssh_run_command]
        expect(command).to include("--dangerously-skip-permissions")
        expect(command).to include("--chrome")
      end

      subject.execute
    end

    it "uses exec to replace shell process" do
      allow(claude_config).to receive(:workspace_path).and_return("/agent-workspace")

      expect(machine).to receive(:action) do |action_name, opts|
        command = opts[:ssh_run_command]
        expect(command).to include("exec claude")
      end

      subject.execute
    end
  end
end
