require 'rspec'
require 'rspec/core'
require 'rspec/mocks'

# Mock Vagrant module structure before loading plugin
module Vagrant
  def self.plugin(version, component = nil)
    if component == :config
      MockConfig
    elsif component == :command
      MockCommand
    else
      MockPlugin
    end
  end

  class MockPlugin
    def self.name(name = nil); end
    def self.description(desc = nil); end
    def self.config(name, &block); end
    def self.command(name, &block); end
  end

  class MockConfig
    UNSET_VALUE = Object.new

    def _detected_errors
      @errors ||= []
    end
  end

  class MockCommand
    attr_accessor :env

    def initialize(argv = [], env = nil)
      @argv = argv
      @env = env
    end

    def parse_options(opts)
      @argv
    end

    def with_target_vms(argv = [], **options, &block)
      # Will be stubbed in tests
    end
  end
end

# Load the plugin
require_relative '../lib/vagrant-claude-sandbox/version'
require_relative '../lib/vagrant-claude-sandbox/config'
require_relative '../lib/vagrant-claude-sandbox/command'
require_relative '../lib/vagrant-claude-sandbox/path_fixer'

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.warnings = true
  config.order = :random
  Kernel.srand config.seed
end
