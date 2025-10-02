# frozen_string_literal: true

require_relative "base"

class TestBunAlpine < TestBase
  @rails_options = "--javascript bun"
  @generate_options = "--alpine"

  def test_bun_alpine
    check_dockerfile
  end
end
