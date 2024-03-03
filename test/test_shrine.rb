# frozen_string_literal: true

require_relative "base"

class TestShrine < TestBase
  @rails_options = "--minimal"

  def app_setup
    system "bundle add shrine"
  end

  def test_shrine
    check_dockerfile
    check_dockerignore
  end
end
