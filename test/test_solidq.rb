# frozen_string_literal: true

require "fileutils"

require_relative "base"

class TestSolidQueue < TestBase
  @rails_options = "--database=postgresql"
  @generate_options = "--compose"

  def app_setup
    system "bundle add solid_queue"
    FileUtils.touch "fly.toml"
  end

  def test_solidq
    check_dockerfile
    check_toml
    check_compose
  end
end
