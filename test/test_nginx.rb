# frozen_string_literal: true

require_relative "base"

class TestNginx < TestBase
  @rails_options = "--minimal"
  @generate_options = "--nginx"

  def test_nginx
    check_dockerfile
    check_entrypoint
  end
end
