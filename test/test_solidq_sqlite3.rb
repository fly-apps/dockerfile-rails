# frozen_string_literal: true

require "fileutils"

require_relative "base"

class TestSolidQueueSqlite3 < TestBase
  @rails_options = "--database=sqlite3"
  @generate_options = "--compose"

  def app_setup
    system "bundle add solid_queue"
    FileUtils.touch "fly.toml"
    IO.write "app/jobs/DummyJob.rb", "class DummyJob < ApplicationJob; end"
  end

  def test_solidq
    check_dockerfile
    check_toml
    check_compose
  end
end
