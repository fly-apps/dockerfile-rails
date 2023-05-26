# frozen_string_literal: true

require "fileutils"

require_relative "base"

class TestSidekiq < TestBase
  @rails_options = "--database=postgresql"
  @generate_options = "--compose"

  def app_setup
    system "bundle add sidekiq"
    FileUtils.touch "fly.toml"
  end

  def test_sidekiq
    check_dockerfile
    check_toml
    check_compose
  end
end
