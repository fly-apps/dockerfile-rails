# frozen_string_literal: true

require "rails"
Rails.env = "test"

require "bundler/gem_tasks"

# Run `rake release` to release a new version of the gem.

require "rake/testtask"
Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList["test/test*.rb"]
  t.verbose = true
end

namespace :test do
  task :capture do
    ENV["TEST_CAPTURE"] = "true"
    Rake::Task[:test].invoke
  end

  task :rubocop do
    sh "rubocop"
  end

  task :system do
    rm_rf "test/tmp/system_test"
    Dir.chdir "test/tmp" do
      sh "rails new system_test --javascript esbuild"
      Dir.chdir "system_test"
      sh "bundle config disable_local_branch_check true"
      sh "bundle config set --local local.dockerfile-rails #{__dir__}"
      sh "bundle add dockerfile-rails --group development " +
        "--git https://github.com/rubys/dockerfile-rails.git"
      sh "bin/rails generate dockerfile --force"
      cp "#{__dir__}/test/docker-entrypoint", "bin"
      IO.write "config/routes.rb",
        'Rails.application.routes.draw {get "/up", to: proc {[200, {}, ["ok"]]}}'
      sh "docker buildx build . --load -t system:test"
      key = IO.read("config/master.key")
      sh "docker run -p 3000:3000 -e RAILS_MASTER_KEY=#{key} --rm system:test"
    end
  ensure
    rm_rf "test/tmp/system_test" unless ENV["TEST_KEEP"]
  end

  task :alpine do
    rm_rf "test/tmp/system_test"
    Dir.chdir "test/tmp" do
      sh "rails new system_test --javascript esbuild --main"
      Dir.chdir "system_test"
      sh "bundle config disable_local_branch_check true"
      sh "bundle config set --local local.dockerfile-rails #{__dir__}"
      sh "bundle add dockerfile-rails --group development " +
        "--git https://github.com/rubys/dockerfile-rails.git"
      sh "bin/rails generate dockerfile --alpine --force"
      cp "#{__dir__}/test/docker-entrypoint", "bin"
      IO.write "config/routes.rb",
        'Rails.application.routes.draw {get "/up", to: proc {[200, {}, ["ok"]]}}'
      sh "docker buildx build . --load -t system:test"
      key = IO.read("config/master.key")
      sh "docker run -p 3000:3000 -e RAILS_MASTER_KEY=#{key} --rm system:test"
    end
  ensure
    rm_rf "test/tmp/system_test" unless ENV["TEST_KEEP"]
  end

  task all: %w(test:rubocop test test:system)
end
