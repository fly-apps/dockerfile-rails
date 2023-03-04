# frozen_string_literal: true

require_relative "base"
require "yaml"

class TestConfig < TestBase
  @rails_options = "--minimal"
  @generate_options = "--fullstaq --no-link --force"

  def app_setup
    IO.write "config/dockerfile.yml",
      YAML.dump("options" => { "yjit" => true })
  end

  def test_config
    check_dockerfile

    options = YAML.load_file("config/dockerfile.yml")["options"]
    assert_equal true, options["yjit"]
    assert_equal true, options["fullstaq"]
    assert_equal false, options["link"]
    assert_nil options["jemalloc"]
  end
end
