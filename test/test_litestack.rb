# frozen_string_literal: true

require_relative "base"

class TestLitestack < TestBase
  def app_setup
    system "bundle add litestack"
  end

  def test_sqlite3
    check_dockerfile
  end
end
