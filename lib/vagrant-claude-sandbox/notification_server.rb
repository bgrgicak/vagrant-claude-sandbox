require 'socket'
require 'json'
require 'yaml'

module VagrantPlugins
  module ClaudeSandbox
    class NotificationServer
      DEFAULT_PORT = 29325
      DEFAULT_CONFIG = {
        'show_types' => ['task_complete', 'needs_input', 'error', 'warning'],
        'default_timeout' => 0,
        'type_timeouts' => {
          'info' => 10,
          'success' => 15,
          'error' => 0,
          'warning' => 0,
          'needs_input' => 0,
          'task_complete' => 0,
          'task_start' => 5
        },
        'enable_sound' => false,
        'require_url' => false
      }

      def initialize(port = DEFAULT_PORT)
        @port = port
        @server = nil
        @config = load_config
      end

      def load_config
        config_path = File.expand_path('~/.vagrant-claude-sandbox/notification_config.yml')
        if File.exist?(config_path)
          begin
            loaded = YAML.load_file(config_path)
            DEFAULT_CONFIG.merge(loaded || {})
          rescue => e
            puts "Warning: Failed to load config from #{config_path}: #{e.message}"
            puts "Using default configuration"
            DEFAULT_CONFIG
          end
        else
          DEFAULT_CONFIG
        end
      end

      def start
        @server = TCPServer.new('127.0.0.1', @port)
        puts "Notification server listening on port #{@port}..."
        puts "VM can now send notifications to this host."
        puts ""
        puts "Configuration:"
        puts "  Show types: #{@config['show_types'].join(', ')}"
        puts "  Default timeout: #{@config['default_timeout'] == 0 ? 'permanent' : "#{@config['default_timeout']}s"}"
        puts "  Require URL: #{@config['require_url']}"
        puts ""
        puts "Press Ctrl+C to stop."

        trap("INT") do
          puts "\nShutting down notification server..."
          @server.close if @server
          exit
        end

        loop do
          client = @server.accept
          handle_client(client)
        end
      rescue Errno::EADDRINUSE
        puts "Error: Port #{@port} is already in use."
        puts "Another notification server may already be running."
        exit 1
      rescue => e
        puts "Error starting notification server: #{e.message}"
        exit 1
      end

      private

      def handle_client(client)
        request = client.gets
        return unless request

        # Parse protocol: NOTIFY|title|message|url|timeout|type (url, timeout, type optional)
        parts = request.strip.split('|', 6)
        if parts[0] == 'NOTIFY' && parts.length >= 3
          title = parts[1]
          message = parts[2]
          url = parts[3] if parts.length >= 4 && !parts[3].to_s.strip.empty?
          timeout_str = parts[4] if parts.length >= 5
          timeout = timeout_str.to_i if timeout_str && !timeout_str.strip.empty?
          type = parts[5] if parts.length >= 6
          type = 'info' if !type || type.strip.empty?
          type = type.strip if type

          # Filter based on configuration
          if should_show_notification?(type, url)
            # Apply configured timeout
            timeout = get_timeout_for_type(type) if timeout.nil?
            send_notification(title, message, url, timeout, type)
            client.puts "OK"
          else
            client.puts "FILTERED"
          end
        else
          client.puts "ERROR: Invalid format. Use: NOTIFY|title|message|url|timeout|type"
        end
      ensure
        client.close
      end

      def should_show_notification?(type, url)
        # Check if this type should be shown
        return false unless @config['show_types'].include?(type)

        # Check if URL is required
        return false if @config['require_url'] && (url.nil? || url.empty?)

        true
      end

      def get_timeout_for_type(type)
        @config['type_timeouts'][type] || @config['default_timeout']
      end

      def send_notification(title, message, url = nil, timeout = nil, type = 'info')
        # Detect OS and send notification
        case RbConfig::CONFIG['host_os']
        when /darwin|mac os/
          send_macos_notification(title, message, url, timeout, type)
        when /linux/
          send_linux_notification(title, message, url, timeout, type)
        else
          puts "[#{type}] #{title}: #{message}"
          puts "  URL: #{url}" if url
          puts "  Timeout: #{timeout}s" if timeout
        end
      end

      def send_macos_notification(title, message, url = nil, timeout = nil, type = 'info')
        # Try terminal-notifier first (more features including clickable notifications)
        if system('which terminal-notifier > /dev/null 2>&1')
          args = ['-title', title, '-message', message]
          args += ['-sound', 'default'] if @config['enable_sound']
          args += ['-open', url] if url
          # terminal-notifier timeout is in seconds, 0 means "stick around until dismissed"
          args += ['-timeout', timeout.to_s] if timeout && timeout > 0
          system('terminal-notifier', *args)
        else
          # Fall back to osascript (not clickable, no timeout control)
          escaped_title = title.gsub('"', '\"')
          escaped_message = message.gsub('"', '\"')
          system("osascript -e 'display notification \"#{escaped_message}\" with title \"#{escaped_title}\"'")
          puts "  (Install terminal-notifier for clickable notifications and timeout control: brew install terminal-notifier)" if url || timeout
        end
      end

      def send_linux_notification(title, message, url = nil, timeout = nil, type = 'info')
        # notify-send supports -t for timeout in milliseconds
        args = [title]

        # Add URL to message if provided
        if url
          full_message = "#{message}\n\n🔗 #{url}"
          args << full_message
        else
          args << message
        end

        # Add timeout if specified (convert seconds to milliseconds, 0 means no timeout)
        if timeout && timeout > 0
          args += ['-t', (timeout * 1000).to_s]
        end

        system('notify-send', *args)
      end
    end
  end
end
