# frozen_string_literal: true

require_relative "base"

class TestPrivateGemserverWithCache < TestBase
  @rails_options = "--minimal"
  @generate_options = "--cache --private-gemserver-domain gems.example.com"

  def test_private_gemserver_with_cache
    check_dockerfile
    check_dockerignore
    check_compose
  end
end
