require_relative 'base'

class TestYjit < TestBase
  @rails_options = '--minimal'
  @generate_options = '--yjit'

  def test_yjit
    check_dockerfile
  end
end
