require_relative 'base'

class TestExecjsImportmap < TestBase
  @rails_options = ''

  def app_setup 
    system 'bundle add execjs'
  end 

  def test_execjs
    check_dockerfile
  end
end
