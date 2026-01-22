require "vagrant-claude-sandbox/version"
require "vagrant-claude-sandbox/plugin"

module VagrantPlugins
  module ClaudeSandbox
    # This returns the path to the source of this plugin.
    def self.source_root
      @source_root ||= Pathname.new(File.expand_path("../../", __FILE__))
    end
  end
end
