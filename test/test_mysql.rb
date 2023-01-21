require_relative 'base'

class TestMysql < TestBase
  @rails_options = '--database=mysql'
  @generate_options = '--compose'

  def test_mysql
    check_dockerfile
    check_compose
  end
end
