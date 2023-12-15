# frozen_string_literal: true

require_relative "base"

class TestAlpine < TestBase
  @generate_options = "--alpine"
  @rails_options = "--javascript=esbuild --database=postgresql"

  def test_postgresql
    check_dockerfile
    check_entrypoint
  end
end
