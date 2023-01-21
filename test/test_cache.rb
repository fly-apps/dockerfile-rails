require_relative 'base'

class TestCache < TestBase
  @rails_options = '--javascript esbuild'
  @generate_options = '--cache'

  def test_cache
    check_dockerfile
  end
end
