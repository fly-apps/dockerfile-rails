# frozen_string_literal: true

require_relative "base"

class TestPrecompileDefer < TestBase
  @rails_options = "" # '--minimal'
  @generate_options = "--precompile=defer"

  def test_precompile_defer
    check_dockerfile
    check_dockerignore
    check_entrypoint
  end
end
