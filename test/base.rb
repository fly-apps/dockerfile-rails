require "minitest/autorun"

class TestBase < Minitest::Test
  make_my_diffs_pretty! 

  class << self
    attr_accessor :rails_options, :generate_options
  end

  def setup
    @appname = self.class.name.sub(/^Test([A-Z])/) {$1.downcase}
    @results = File.expand_path(@appname, 'test/results')

    Dir.chdir 'test/tmp'

    system "rails new #{self.class.rails_options} #{@appname}"

    Dir.chdir @appname

    system 'bundle add dockerfile-rails --group development'
    system "bin/rails generate dockerfile #{self.class.generate_options}"
  end

  def check_dockerfile
    results = IO.read('Dockerfile')
      .gsub(/(^ARG\s+\w+\s*=).*/, '\1')

    expected = IO.read("#{@results}/Dockerfile")
      .gsub(/(^ARG\s+\w+\s*=).*/, '\1')

    assert_equal expected, results
  end

  def check_compose
    results = IO.read('docker-compose.yml')
    expected = IO.read("#{@results}/docker-compose.yml")
    
    assert_equal expected, results
  end

  def teardown
    Dir.chdir '..'
    FileUtils.rm_rf @appname
    Dir.chdir '../..'
  end
end
