# frozen_string_literal: true

require_relative "base"

class TestJemalloc < TestBase
  @rails_options = "--minimal"
  @generate_options = "--jemalloc --platform=linux/amd64"

  def test_jemalloc
    check_dockerfile
  end
end
