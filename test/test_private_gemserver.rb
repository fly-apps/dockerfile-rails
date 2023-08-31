# frozen_string_literal: true

require_relative "base"

class TestPrivateGemserver < TestBase
  @rails_options = "--minimal"
  @generate_options = "--compose --private-gemserver-domain gems.example.com"

  def test_private_gemserver
    check_dockerfile
    check_dockerignore
    check_compose
  end
end
