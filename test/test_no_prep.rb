# frozen_string_literal: true

require_relative "base"

class TestNoPrep < TestBase
  @rails_options = "--minimal"
  @generate_options = "--no-prepare"

  def app_setup
    FileUtils.touch "fly.toml"
  end

  def test_no_prep
    check_dockerfile
    check_entrypoint
    check_toml
  end
end
