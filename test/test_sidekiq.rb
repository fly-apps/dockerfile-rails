require_relative 'base'

class TestSidekiq < TestBase
  @rails_options = '--database=postgresql'
  @generate_options = '--compose'

  def app_setup 
    system 'bundle add sidekiq'
  end 

  def test_sidekiq
    check_compose
  end
end
