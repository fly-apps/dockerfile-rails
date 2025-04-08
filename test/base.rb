# frozen_string_literal: true

require "minitest/autorun"

require "active_support"
require "active_support/core_ext/string/inflections"

require "bundler"

class TestBase < Minitest::Test
  make_my_diffs_pretty!

  class << self
    attr_accessor :rails_options, :generate_options
  end

  def app_setup
  end

  def setup
    @capture = ENV["TEST_CAPTURE"]

    @appname = self.class.name.underscore
    @results = File.expand_path(@appname.sub("test_", ""), "test/results")
    FileUtils.mkdir_p @results if @capture

    Dir.chdir "test/tmp"

    FileUtils.rm_rf @appname
    Bundler.with_unbundled_env do
      system "rails new #{@appname} #{self.class.rails_options}"

      Dir.chdir @appname

      app_setup

      system "bundle config disable_local_branch_check true"
      system "bundle config set --local local.dockerfile-rails #{File.expand_path('..', __dir__)}"
      system "bundle add dockerfile-rails --git https://github.com/rubys/dockerfile-rails.git --group development"

      ENV["RAILS_ENV"] = "test"
      system "bin/rails generate dockerfile #{self.class.generate_options} --force"
    end
  end

  def check_dockerfile
    results = IO.read("Dockerfile")
      .gsub(/(^ARG\s+\w+\s*=).*?(\s*\\?$)/, '\1xxx\2')

    IO.write("#{@results}/Dockerfile", results) if @capture

    expected = IO.read("#{@results}/Dockerfile")
      .gsub(/(^ARG\s+\w+\s*=).*?(\s*\\?$)/, '\1xxx\2')

    assert_equal expected, results
  end

  def check_dockerignore
    results = IO.read(".dockerignore")

    IO.write("#{@results}/.dockerignore", results) if @capture

    expected = IO.read("#{@results}/.dockerignore")

    assert_equal expected, results
  end

  def check_compose
    results = IO.read("docker-compose.yml")

    IO.write("#{@results}/docker-compose.yml", results) if @capture

    expected = IO.read("#{@results}/docker-compose.yml")

    assert_equal expected, results
  end

  def check_toml
    results = IO.read("fly.toml")

    if @capture
      IO.write("#{@results}/fly.toml", results)
    end

    expected = IO.read("#{@results}/fly.toml")

    assert_equal expected, results
  end

  def check_litefs
    results = IO.read("config/litefs.yml")

    if @capture
      FileUtils.mkdir_p "#{@results}/config"
      IO.write("#{@results}/config/litefs.yml", results)
    end

    expected = IO.read("#{@results}/config/litefs.yml")

    assert_equal expected, results
  end

  def check_entrypoint
    results = IO.read("bin/docker-entrypoint")

    IO.write("#{@results}/docker-entrypoint", results) if @capture

    expected = IO.read("#{@results}/docker-entrypoint")

    assert_equal expected, results
  end

  def check_database_config
    results = IO.read("config/database.yml")

    IO.write("#{@results}/database.yml", results) if @capture

    expected = IO.read("#{@results}/database.yml")

    assert_equal expected, results
  end

  def check_puma
    results = IO.read("config/puma.rb")

    IO.write("#{@results}/puma.rb", results) if @capture

    expected = IO.read("#{@results}/puma.rb")

    assert_equal expected, results
  end

  def check_raketask
    results = IO.read("lib/tasks/litestream.rake")

    IO.write("#{@results}/litestream.rake", results) if @capture

    expected = IO.read("#{@results}/litestream.rake")

    assert_equal expected, results
  end

  def teardown
    return if ENV["TEST_KEEP"]
    Dir.chdir ".."
    FileUtils.rm_rf @appname
    Dir.chdir "../.."
  end
end
