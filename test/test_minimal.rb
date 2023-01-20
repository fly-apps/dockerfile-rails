require 'test/unit'

class TestMinimal < Test::Unit::TestCase
  def test_minimal
    Dir.chdir 'test/tmp' do
      system 'bundle exec rails new --minimal minimal'

      Bundler.with_original_env do
        Dir.chdir 'minimal' do
          system 'bundle add dockerfile-rails --group development'
          system 'bin/rails generate dockerfile'
        end
      end

      results = IO.read('minimal/Dockerfile')
        .gsub(/(^ARG\s+\w+\s*=).*/, '\1')

      expected = IO.read('../results/minimal/Dockerfile')
        .gsub(/(^ARG\s+\w+\s*=).*/, '\1')
      
      assert_equal expected, results
    end
  ensure
    FileUtils.rm_rf 'test/tmp/minimal'
  end
end
