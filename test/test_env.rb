# frozen_string_literal: true

require_relative "base"

class TestEnv < TestBase
  @rails_options = "--minimal"
  @generate_options = "--env-build=AWS_ACCESS_KEY_ID:1 AWS_SECRET_ACCESS_KEY:1"

  def test_env
    check_dockerfile
  end
end
