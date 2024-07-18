# frozen_string_literal: true

require_relative "base"

class TestArg < TestBase
  @rails_options = "--minimal"
  @generate_options = "--arg-build=FOO:BAR COMMIT"

  def test_env
    check_dockerfile
  end
end
