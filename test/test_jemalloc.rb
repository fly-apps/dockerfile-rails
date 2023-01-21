require_relative 'base'

class TestJemalloc < TestBase
  @rails_options = '--minimal'
  @generate_options = '--jemalloc'

  def test_jemalloc
    check_dockerfile
  end
end
