require_relative 'base'

class TestGrover < TestBase
  @rails_options = '--minimal'

  def app_setup 
    system 'bundle add grover'
    system 'npm install puppeteer'
  end 

  def test_grover
    check_dockerfile
  end
end
