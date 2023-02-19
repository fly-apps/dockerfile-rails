# frozen_string_literal: true

require_relative "base"

class TestExecjsNode < TestBase
  @rails_options = "--javascript esbuild"

  def app_setup
    system "bundle add execjs"
  end

  def test_execjs
    check_dockerfile
  end
end
