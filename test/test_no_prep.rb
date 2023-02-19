# frozen_string_literal: true

require_relative "base"

class TestNoPrep < TestBase
  @rails_options = "--minimal"
  @generate_options = "--no-prepare"

  def test_no_prep
    check_dockerfile
    check_entrypoint
  end
end
