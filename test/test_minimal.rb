require "minitest/autorun"

class TestMinimal < Minitest::Test
  make_my_diffs_pretty! 

  def test_minimal
    Dir.chdir 'test/tmp' do
      system 'rails new --minimal minimal'

      Dir.chdir 'minimal' do
	system 'bundle add dockerfile-rails --group development'
	system 'bin/rails generate dockerfile'
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
