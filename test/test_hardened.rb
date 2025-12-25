# frozen_string_literal: true

require_relative "base"
require "yaml"

class TestHardened < TestBase
  @rails_options = "--minimal"
  @generate_options = "--hardened"

  def test_hardened
    check_dockerfile

    options = YAML.load_file("config/dockerfile.yml")["options"]
    assert_equal true, options["hardened"]
  end
end
