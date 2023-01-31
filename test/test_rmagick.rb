require_relative 'base'

class TestRmagick < TestBase
  @rails_options = '--minimal'

  def app_setup 
    system 'bundle add rmagick'
  end 

  def test_rmagick
    check_dockerfile
  end
end
