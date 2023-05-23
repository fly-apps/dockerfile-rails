# frozen_string_literal: true

require_relative "base"

class TestLitefs < TestBase
  @rails_options = "--database=sqlite3"
  @generate_options = "--litefs"

  def test_sqlite3
    check_dockerfile
    check_entrypoint
    check_litefs
  end
end
