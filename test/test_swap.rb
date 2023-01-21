require_relative 'base'

class TestSwap < TestBase
  @rails_options = '--minimal'
  @generate_options = '--swap=512M'

  def test_swap
    check_entrypoint
  end
end
