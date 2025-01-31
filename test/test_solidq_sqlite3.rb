# frozen_string_literal: true

require "fileutils"

require_relative "base"

class TestSolidQueueSqlite3 < TestBase
  @rails_options = "--database=sqlite3 --main"

  def app_setup
    FileUtils.touch "fly.toml"
    FileUtils.mkdir_p "app/jobs"
    IO.write "app/jobs/DummyJob.rb", "class DummyJob < ApplicationJob; end"
  end

  def test_solidq
    check_dockerfile
    check_toml
    check_puma
  end
end
