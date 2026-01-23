require_relative 'lib/vagrant-claude-sandbox/version'

Gem::Specification.new do |spec|
  spec.name          = "vagrant-claude-sandbox"
  spec.version       = VagrantPlugins::ClaudeSandbox::VERSION
  spec.authors       = ["Bero"]
  spec.summary       = "Vagrant plugin for Claude Code sandbox environment"
  spec.description   = "Provides a pre-configured sandbox environment for running Claude Code in an isolated VM with full plugin and skills support"
  spec.homepage      = "https://github.com/bgrgicak/vagrant-claude-sandbox"
  spec.license       = "MIT"

  spec.metadata = {
    "source_code_uri" => "https://github.com/bgrgicak/vagrant-claude-sandbox",
    "bug_tracker_uri" => "https://github.com/bgrgicak/vagrant-claude-sandbox/issues"
  }

  spec.required_ruby_version = ">= 2.6.0"

  spec.files = Dir[
    "lib/**/*.rb",
    "lib/docker/Dockerfile",
    "README.md",
    "LICENSE"
  ]

  spec.require_paths = ["lib"]

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.12"
end
