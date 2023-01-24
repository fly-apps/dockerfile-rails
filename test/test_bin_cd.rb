require_relative 'base'

class TestBinCd < TestBase
  @rails_options = '--minimal'
  @generate_options = '--bin-cd'

  def test_bin_cd
    check_dockerfile
  end
end
