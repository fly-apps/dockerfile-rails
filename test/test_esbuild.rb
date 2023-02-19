# frozen_string_literal: true

require_relative "base"
require "json"

class TestEsbuild < TestBase
  @rails_options = "--javascript esbuild"
  @generate_options = "--compose"

  def test_esbuild
    check_dockerfile
    check_dockerignore
    check_compose

    package = JSON.parse(IO.read("package.json"))
    assert_includes package["packageManager"], "yarn@"
  end
end
