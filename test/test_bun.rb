# frozen_string_literal: true

require_relative "base"
require "json"

class TestBun < TestBase
  @rails_options = "--main --javascript bun"
  @generate_options = "--compose"

  def test_esbuild
    check_dockerfile
    check_dockerignore
    check_compose

    package = JSON.parse(IO.read("package.json"))
    assert_includes package["packageManager"], "yarn@"
  end
end
