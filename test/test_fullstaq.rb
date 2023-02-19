# frozen_string_literal: true

require_relative "base"

class TestFullstaq < TestBase
  @rails_options = "--minimal"
  @generate_options = "--fullstaq"

  def test_fullstaq
    check_dockerfile
  end
end
