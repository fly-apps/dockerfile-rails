require "minitest/autorun"

class TestPostgresql < Minitest::Test
  make_my_diffs_pretty! 

  def test_postgresql
    Dir.chdir 'test/tmp' do
      system 'bundle exec rails new --database=postgresql postgresql'

      Dir.chdir 'postgresql' do
        system 'bundle add dockerfile-rails --group development'
        system 'bin/rails generate dockerfile --compose'
      end

      # Dockerfile
      results = IO.read('postgresql/Dockerfile')
        .gsub(/(^ARG\s+\w+\s*=).*/, '\1')

      expected = IO.read('../results/postgresql/Dockerfile')
        .gsub(/(^ARG\s+\w+\s*=).*/, '\1')
      
      assert_equal expected, results

      # docker-compose.yml
      results = IO.read('postgresql/docker-compose.yml')
        .gsub(/(^ARG\s+\w+\s*=).*/, '\1')

      expected = IO.read('../results/postgresql/docker-compose.yml')
        .gsub(/(^ARG\s+\w+\s*=).*/, '\1')
      
      assert_equal expected, results
    end
  ensure
    FileUtils.rm_rf 'test/tmp/postgresql'
  end
end
