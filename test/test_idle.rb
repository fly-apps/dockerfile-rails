# frozen_string_literal: true

require_relative "base"

class TestIdle < TestBase
  @rails_options = "--minimal"
  @generate_options = "--max-idle=5m --swap=512M"

  def test_idle
    check_dockerfile
    check_entrypoint
  end
end
