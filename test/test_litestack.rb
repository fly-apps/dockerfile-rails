# frozen_string_literal: true

require_relative "base"

# test disabled due to:
# `method_missing': undefined method `sqlite3_production_warning=' for class ActiveRecord::Base (NoMethodError)

class TestLitestack # < TestBase
  def app_setup
    system "bundle add litestack"
  end

  def test_sqlite3
    check_dockerfile
  end
end
