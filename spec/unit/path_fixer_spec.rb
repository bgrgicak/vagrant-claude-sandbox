require 'spec_helper'

describe VagrantPlugins::ClaudeSandbox::PathFixer do
  describe ".find_docker_binary" do
    it "returns path if docker exists in /usr/local/bin" do
      allow(File).to receive(:executable?).with('/usr/local/bin/docker').and_return(true)
      expect(described_class.send(:find_docker_binary)).to eq('/usr/local/bin/docker')
    end

    it "returns path if docker exists in /usr/bin" do
      allow(File).to receive(:executable?).with('/usr/local/bin/docker').and_return(false)
      allow(File).to receive(:executable?).with('/usr/bin/docker').and_return(true)
      expect(described_class.send(:find_docker_binary)).to eq('/usr/bin/docker')
    end

    it "returns path if docker exists in /opt/homebrew/bin" do
      allow(File).to receive(:executable?).with('/usr/local/bin/docker').and_return(false)
      allow(File).to receive(:executable?).with('/usr/bin/docker').and_return(false)
      allow(File).to receive(:executable?).with('/opt/homebrew/bin/docker').and_return(true)
      expect(described_class.send(:find_docker_binary)).to eq('/opt/homebrew/bin/docker')
    end

    it "falls back to which command" do
      allow(File).to receive(:executable?).and_return(false)
      allow(described_class).to receive(:`).with('which docker 2>/dev/null').and_return("/custom/path/docker\n")
      expect(described_class.send(:find_docker_binary)).to eq('/custom/path/docker')
    end

    it "returns nil if docker is not found" do
      allow(File).to receive(:executable?).and_return(false)
      allow(described_class).to receive(:`).with('which docker 2>/dev/null').and_return("")
      expect(described_class.send(:find_docker_binary)).to be_nil
    end

    it "returns nil if which command raises exception" do
      allow(File).to receive(:executable?).and_return(false)
      allow(described_class).to receive(:`).and_raise(StandardError)
      expect(described_class.send(:find_docker_binary)).to be_nil
    end
  end

  describe ".using_docker_related_command?" do
    before do
      @original_argv = ARGV.dup
      @original_env = ENV['VAGRANT_DEFAULT_PROVIDER']
    end

    after do
      ARGV.replace(@original_argv)
      ENV['VAGRANT_DEFAULT_PROVIDER'] = @original_env
    end

    it "returns true when --provider=docker is in ARGV" do
      ARGV.replace(['up', '--provider=docker'])
      expect(described_class.send(:using_docker_related_command?)).to be true
    end

    it "returns true when --provider docker is in ARGV" do
      ARGV.replace(['up', '--provider', 'docker'])
      expect(described_class.send(:using_docker_related_command?)).to be true
    end

    it "returns true when VAGRANT_DEFAULT_PROVIDER is docker" do
      ENV['VAGRANT_DEFAULT_PROVIDER'] = 'docker'
      ARGV.replace(['up'])
      expect(described_class.send(:using_docker_related_command?)).to be true
    end

    it "returns true for up command" do
      ARGV.replace(['up'])
      expect(described_class.send(:using_docker_related_command?)).to be true
    end

    it "returns true for destroy command" do
      ARGV.replace(['destroy'])
      expect(described_class.send(:using_docker_related_command?)).to be true
    end

    it "returns true for halt command" do
      ARGV.replace(['halt'])
      expect(described_class.send(:using_docker_related_command?)).to be true
    end

    it "returns true for reload command" do
      ARGV.replace(['reload'])
      expect(described_class.send(:using_docker_related_command?)).to be true
    end

    it "returns true for ssh command" do
      ARGV.replace(['ssh'])
      expect(described_class.send(:using_docker_related_command?)).to be true
    end

    it "returns false for other commands" do
      ARGV.replace(['status'])
      ENV['VAGRANT_DEFAULT_PROVIDER'] = nil
      expect(described_class.send(:using_docker_related_command?)).to be false
    end
  end

  describe ".fix_docker_path!" do
    let(:original_path) { ENV['PATH'] }

    before do
      @original_path = ENV['PATH']
      @original_argv = ARGV.dup
    end

    after do
      ENV['PATH'] = @original_path
      ARGV.replace(@original_argv)
    end

    context "when docker binary is not found" do
      it "does not modify PATH" do
        allow(described_class).to receive(:find_docker_binary).and_return(nil)
        original = ENV['PATH']
        described_class.fix_docker_path!
        expect(ENV['PATH']).to eq(original)
      end
    end

    context "when no PATH conflict exists" do
      it "does not modify PATH" do
        allow(described_class).to receive(:find_docker_binary).and_return('/usr/local/bin/docker')
        ENV['PATH'] = '/usr/local/bin:/usr/bin:/bin'
        allow(File).to receive(:exist?).and_return(false)

        original = ENV['PATH']
        described_class.fix_docker_path!
        expect(ENV['PATH']).to eq(original)
      end
    end

    context "when PATH conflict exists" do
      it "reorders PATH to prioritize docker binary location" do
        allow(described_class).to receive(:find_docker_binary).and_return('/usr/local/bin/docker')
        allow(described_class).to receive(:using_docker_related_command?).and_return(false)

        # Set up a PATH with a conflicting 'docker' directory
        ENV['PATH'] = '/home/user/projects/docker:/opt/bin:/usr/local/bin:/usr/bin'

        # Mock the directory check
        allow(File).to receive(:exist?).with('/home/user/projects/docker/docker').and_return(true)
        allow(File).to receive(:directory?).with('/home/user/projects/docker/docker').and_return(true)
        allow(File).to receive(:exist?).with('/opt/bin/docker').and_return(false)

        described_class.fix_docker_path!

        # Verify PATH was reordered
        path_dirs = ENV['PATH'].split(':')
        docker_dir_index = path_dirs.index('/usr/local/bin')
        conflict_dir_index = path_dirs.index('/home/user/projects/docker')

        expect(docker_dir_index).to be < conflict_dir_index
      end

      it "outputs message when using docker-related command" do
        allow(described_class).to receive(:find_docker_binary).and_return('/usr/local/bin/docker')
        allow(described_class).to receive(:using_docker_related_command?).and_return(true)

        ENV['PATH'] = '/home/user/projects/docker:/usr/local/bin:/usr/bin'
        allow(File).to receive(:exist?).with('/home/user/projects/docker/docker').and_return(true)
        allow(File).to receive(:directory?).with('/home/user/projects/docker/docker').and_return(true)

        expect { described_class.fix_docker_path! }.to output(/Detected Docker PATH conflict/).to_stdout
      end

      it "does not output message when not using docker-related command" do
        allow(described_class).to receive(:find_docker_binary).and_return('/usr/local/bin/docker')
        allow(described_class).to receive(:using_docker_related_command?).and_return(false)

        ENV['PATH'] = '/home/user/projects/docker:/usr/local/bin:/usr/bin'
        allow(File).to receive(:exist?).with('/home/user/projects/docker/docker').and_return(true)
        allow(File).to receive(:directory?).with('/home/user/projects/docker/docker').and_return(true)

        expect { described_class.fix_docker_path! }.not_to output.to_stdout
      end
    end

    context "when docker directory appears after real docker binary" do
      it "does not modify PATH" do
        allow(described_class).to receive(:find_docker_binary).and_return('/usr/local/bin/docker')
        ENV['PATH'] = '/usr/local/bin:/usr/bin:/home/user/projects/docker'

        original = ENV['PATH']
        described_class.fix_docker_path!
        expect(ENV['PATH']).to eq(original)
      end
    end

    context "with multiple conflicting directories" do
      it "reorders PATH correctly" do
        allow(described_class).to receive(:find_docker_binary).and_return('/usr/bin/docker')
        allow(described_class).to receive(:using_docker_related_command?).and_return(false)

        ENV['PATH'] = '/home/user/projects/docker:/opt/myapp/docker:/usr/local/bin:/usr/bin'

        allow(File).to receive(:exist?).with('/home/user/projects/docker/docker').and_return(true)
        allow(File).to receive(:directory?).with('/home/user/projects/docker/docker').and_return(true)
        allow(File).to receive(:exist?).with('/opt/myapp/docker/docker').and_return(false)
        allow(File).to receive(:exist?).with('/usr/local/bin/docker').and_return(false)

        described_class.fix_docker_path!

        # Verify real docker directory comes first
        path_dirs = ENV['PATH'].split(':')
        docker_dir_index = path_dirs.index('/usr/bin')
        conflict_dir_index = path_dirs.index('/home/user/projects/docker')

        expect(docker_dir_index).to eq(0).or eq(1).or eq(2) # Should be in first 3 positions
        expect(docker_dir_index).to be < conflict_dir_index
      end
    end
  end
end
