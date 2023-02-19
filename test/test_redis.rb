# frozen_string_literal: true

require_relative "base"

class TestRedis < TestBase
  @rails_options = ""
  @generate_options = "--compose"

  def app_setup
    system "bin/rails generate channel counter"
  end

  def test_redis
    check_dockerfile
    check_compose
  end
end
