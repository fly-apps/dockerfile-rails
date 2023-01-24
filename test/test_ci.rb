require_relative 'base'

class TestCi < TestBase
  @rails_options = '--minimal'
  @generate_options = '--ci'

  def test_ci
    check_dockerfile
  end
end
