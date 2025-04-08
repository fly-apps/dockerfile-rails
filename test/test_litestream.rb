# frozen_string_literal: true

require_relative "base"

class TestLitestream < TestBase
  @rails_options = "--database=sqlite3"
  @generate_options = "--litestream"

  def app_setup
    FileUtils.touch "fly.toml"
  end

  def test_litestream
    check_dockerfile
    check_entrypoint
    check_toml
    check_raketask
  end
end
