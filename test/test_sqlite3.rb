# frozen_string_literal: true

require_relative "base"

class TestSqlite3 < TestBase
  @rails_options = "--database=sqlite3"
  @generate_options = "--compose"

  def test_sqlite3
    check_dockerfile
    check_compose
  end
end
