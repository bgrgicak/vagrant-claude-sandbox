require_relative 'lib/vagrant-claude-sandbox/version'

Gem::Specification.new do |spec|
  spec.name          = "vagrant-claude-sandbox"
  spec.version       = VagrantPlugins::ClaudeSandbox::VERSION
  spec.authors       = ["Bero"]
  spec.email         = [""]
  spec.summary       = "Vagrant plugin for Claude Code sandbox environment"
  spec.description   = "Provides a pre-configured sandbox environment for running Claude Code in an isolated VM with full plugin and skills support"
  spec.homepage      = "https://github.com/yourusername/vagrant-claude-sandbox"
  spec.license       = "MIT"

  spec.required_ruby_version = ">= 2.6.0"

  spec.files = Dir[
    "lib/**/*.rb",
    "README.md",
    "LICENSE",
    "CHANGELOG.md"
  ]

  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
end
