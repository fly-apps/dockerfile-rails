# frozen_string_literal: true

require_relative "base"

class TestPostgresql < TestBase
  @rails_options = "--database=postgresql --main"
  @generate_options = "--compose"

  def test_postgresql
    check_dockerfile
    check_compose
    check_database_config
  end
end
