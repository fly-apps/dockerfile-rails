# frozen_string_literal: true

require_relative "base"

class TestParallel < TestBase
  @rails_options = "--javascript esbuild"
  @generate_options = "--parallel"

  def test_parallel
    check_dockerfile
  end
end
