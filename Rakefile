require 'rspec/core/rake_task'

desc 'Run unit tests'
RSpec::Core::RakeTask.new(:spec) do |t|
  t.pattern = 'spec/unit/**/*_spec.rb'
  t.rspec_opts = ['--color', '--format', 'documentation']
end

desc 'Run integration tests'
task :integration do
  puts "Running integration tests..."
  sh './test-plugin.sh'
end

desc 'Run all tests (unit + integration)'
task :test => [:spec, :integration]

task :default => :spec
