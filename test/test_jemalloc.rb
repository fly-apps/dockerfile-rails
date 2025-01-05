# frozen_string_literal: true

require_relative "base"

class TestJemalloc < TestBase
  @rails_options = "--minimal"
  @generate_options = "--no-jemalloc"

  def test_jemalloc
    check_dockerfile
    check_entrypoint
  end
end
