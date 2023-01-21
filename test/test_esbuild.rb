require_relative 'base'

class TestEsbuild < TestBase
  @rails_options = '--javascript esbuild'
  @generate_options = '--compose'

  def test_esbuild
    check_dockerfile
    check_compose
  end
end
