require_relative 'base'
require 'json'

class TestVite < TestBase
  @rails_options = '--minimal'

  def app_setup 
    system 'bundle add vite_ruby'
    system 'bundle exec vite install'
  end 

  def test_vite
    check_dockerfile
    check_dockerignore

    package = JSON.load_file('package.json')
    assert_equal 'vite build --outDir public', package.dig('scripts', 'build')
  end
end
