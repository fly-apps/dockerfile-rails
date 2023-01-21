require "bundler/gem_tasks"

# Run `rake release` to release a new version of the gem.

require 'rake/testtask'
Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList['test/test*.rb']
  t.verbose = true
end

namespace :test do
  task :capture do
    ENV['TEST_CAPTURE'] = 'true'
    Rake::Task[:test].invoke
  end
end
