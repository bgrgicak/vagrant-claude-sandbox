module VagrantPlugins
  module ClaudeSandbox
    class PathFixer
      def self.fix_docker_path!
        # Always check for PATH conflicts and fix them
        # This is necessary because commands like 'vagrant destroy' don't have --provider flag
        # but still need the correct PATH to interact with Docker containers

        # Check if there's a PATH conflict
        path_dirs = ENV['PATH'].split(':')
        docker_binary_path = find_docker_binary

        return unless docker_binary_path

        docker_dir = File.dirname(docker_binary_path)

        # Check if there's a directory named 'docker' appearing before the real docker binary
        conflict_detected = false
        path_dirs.each_with_index do |dir, index|
          # If we find the real docker directory, stop checking
          break if dir == docker_dir

          # Check if this directory has a 'docker' subdirectory or file that would conflict
          potential_conflict = File.join(dir, 'docker')
          if File.exist?(potential_conflict) && File.directory?(potential_conflict)
            conflict_detected = true
            break
          end
        end

        if conflict_detected
          # Reorder PATH to put common Docker binary locations first
          prioritized_paths = ['/usr/local/bin', '/usr/bin', docker_dir].uniq
          other_paths = path_dirs - prioritized_paths
          new_path = (prioritized_paths + other_paths).join(':')

          ENV['PATH'] = new_path
          # Only show message for commands that actually use Docker
          if using_docker_related_command?
            puts "Detected Docker PATH conflict - automatically reordered PATH"
          end
        end
      end

      private

      def self.using_docker_related_command?
        # Check if this is a Docker-related command
        ARGV.include?('--provider=docker') ||
        ARGV.include?('--provider docker') ||
        ENV['VAGRANT_DEFAULT_PROVIDER'] == 'docker' ||
        ARGV.include?('up') ||
        ARGV.include?('destroy') ||
        ARGV.include?('halt') ||
        ARGV.include?('reload') ||
        ARGV.include?('ssh')
      end

      def self.find_docker_binary
        # Try common Docker installation paths
        ['/usr/local/bin/docker', '/usr/bin/docker', '/opt/homebrew/bin/docker'].each do |path|
          return path if File.executable?(path)
        end

        # Fall back to using 'which' if available
        result = `which docker 2>/dev/null`.strip
        result.empty? ? nil : result
      rescue
        nil
      end
    end
  end
end
