# frozen_string_literal: true

require_relative "base"
require "json"

class TestBun < TestBase
  @rails_options = "--javascript bun"
  @generate_options = "--compose"

  def test_bun
    check_dockerfile
    check_dockerignore
    check_compose
  end
end
