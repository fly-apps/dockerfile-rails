# frozen_string_literal: true

require_relative "base"

class TestAPI < TestBase
  @rails_options = "--api"
  @generate_options = "--compose"

  def app_setup
    system "npx -y nano-react-app my-app"
  end

  def test_api
    check_dockerfile
    check_compose
  end
end
