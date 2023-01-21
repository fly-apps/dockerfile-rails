require 'erb'
require_relative '../dockerfile-rails/scanner.rb'

class DockerfileGenerator < Rails::Generators::Base
  include DockerfileRails::Scanner

  class_option :ci, type: :boolean, default: false,
    desc: 'include test gems in bundle'

  class_option :cache, type: :boolean, default: false,
    desc: 'use build cache to speed up installs'

  class_option :parallel, type: :boolean, default: false,
    desc: 'use build stages to install gems and node modules in parallel'

  class_option :swap, type: :string, default: nil,
    desc: 'allocate swapspace'

  class_option :compose, type: :boolean, default: false,
    desc: 'generate a docker-compose.yml file'

  class_option :redis, type: :boolean, default: false,
    desc: 'include redis libraries'

  class_option :sqlite3, aliases: '--sqlite', type: :boolean, default: false,
    desc: 'include sqlite3 libraries'

  class_option :postgresql, aliases: '--postgres', type: :boolean, default: false,
    desc: 'include postgresql libraries'

  class_option :mysql, type: :boolean, default: false,
    desc: 'include mysql libraries'

  class_option :platform, type: :string, default: nil,
    desc: 'image platform (example: linux/arm64)'

  class_option :jemalloc, type: :boolean, default: false,
    desc: 'use jemalloc alternative malloc implementation'
  
  class_option :fullstaq, type: :boolean, default: false,
    descr: 'use Fullstaq Ruby image from Quay.io'

  class_option :yjit, type: :boolean, default: false,
    desc: 'enable YJIT optimizing compiler'

  def generate_app
    source_paths.push File.expand_path('./templates', __dir__)

    scan_rails_app

    template 'Dockerfile.erb', 'Dockerfile'
    template 'dockerignore.erb', '.dockerignore'

    template 'node-version.erb', '.node-version' if using_node?

    template 'docker-entrypoint.erb', 'bin/docker-entrypoint'
    chmod "bin/docker-entrypoint", 0755 & ~File.umask, verbose: false

    template 'docker-compose.yml.erb', 'docker-compose.yml' if options.compose
  end

private
   
  def render(options)
    scope = (Class.new do
      def initialize(obj, locals)
        @_obj = obj
        @_locals = OpenStruct.new(locals)
      end

      def method_missing(method, *args, &block)
        if @_locals.respond_to? method
          @_locals.send method, *args, &block
        else
          @_obj.send method, *args, &block
        end
      end

      def get_binding
        binding
      end
    end).new(self, options[:locals] || {})

    template = IO.read(File.join(source_paths.last, "_#{options[:partial]}.erb"))
    ERB.new(template, trim_mode: '-').result(scope.get_binding).strip
  end

  def platform
    if options.platform
      "--platform #{options.platform} "
    else
      ""
    end
  end

  def using_node?
    return @using_node if @using_node != nil
    @using_node = File.exist? 'package.json'
  end

  def using_redis?
    options.redis? or @redis
  end

  def using_execjs?
    @gemfile.include? 'execjs'
  end

  def parallel?
    using_node? && options.parallel
  end

  def keeps?
    return @keeps if @keeps != nil
    @keeps = !Dir['**/.keep']
  end

  def build_packages
    # start with the essentials
    packages = %w(build-essential)

    # add databases: sqlite3, postgres, mysql
    packages << 'pkg-config' if options.sqlite3? or @sqlite3
    packages << 'libpq-dev' if options.postgresql? or @postgresql
    packages << 'default-libmysqlclient-dev' if options.mysql or @mysql

    # add git if needed to install gems
    packages << 'git' if @git

    # add redis in case Action Cable, caching, or sidekiq are added later
    packages << "redis" if using_redis?

    # ActiveStorage preview support
    packages << "libvips" if @gemfile.include? 'ruby-vips'

    # Rmagick gem
    packages += %w[pkg-config libmagickwand-dev] if @gemfile.include? 'rmagick'

    # node support, including support for building native modules
    if using_node?
      packages += %w(node-gyp pkg-config)
      packages += %w(curl unzip) unless using_execjs?

      # module build process depends on Python, and debian changed
      # how python is installed with the bullseye release.  Below
      # is based on debian release included with the Ruby images on
      # Dockerhub.
      case Gem.ruby_version
      when /^2.7/
        bullseye = ruby_version >= "2.7.4"
      when /^3.0/
        bullseye = ruby_version >= "3.0.2"
      else
        bullseye = true
      end

      if bullseye
        packages << "python-is-python3"
      else
        packages << "python"
      end
    end

    packages.sort.uniq
  end

  def deploy_packages
    packages = []

    # start with databases: sqlite3, postgres, mysql
    packages << 'libsqlite3-0' if options.sqlite3? or @sqlite3
    packages << 'postgresql-client' if options.postgresql? or @postgresql
    packages << 'default-mysql-client' if options.mysql or @mysql

    # add redis in case Action Cable, caching, or sidekiq are added later
    packages << "redis" if using_redis?

    # ActiveStorage preview support
    packages << "libvips" if @gemfile.include? 'ruby-vips'

    # Rmagick gem
    packages << 'imagemagick' if @gemfile.include? 'rmagick'

    packages.sort
  end

  def binfile_fixups
    # binfiles may have OS specific paths to ruby.  Normalize them.
    shebangs = Dir["bin/*"].map { |file| IO.read(file).lines.first }.join
    rubies = shebangs.scan(%r{#!/usr/bin/env (ruby.*)}).flatten.uniq
  
    binfixups = (rubies - %w(ruby)).map do |ruby|
      "sed -i 's/#{Regexp.quote(ruby)}$/ruby/' bin/*"
    end
                                        
    # Windows line endings will cause scripts to fail.  If any
    # or found OR this generation is run on a windows platform 
    # and there are other binfixups required, then convert 
    # line endings.  This avoids adding unnecessary fixups if
    # none are required, but prepares for the need to do the
    # fix line endings if other fixups are required.
    has_cr = Dir["bin/*"].any? { |file| IO.read(file).include? "\r" }
    if has_cr || (Gem.win_platform? && !binfixups.empty?)
      binfixups.unshift 'sed -i "s/\r$//g" bin/*'
    end
    
    # Windows file systems may not have the concept of executable.
    # In such cases, fix up during the build.
    unless Dir["bin/*"].all? { |file| File.executable? file }
      binfixups.unshift "chmod +x bin/*"
    end

    binfixups
  end

  def deploy_database
    if options.postgresql? or @postgresql
      'postgresql'
    elsif options.mysql or @mysql
      'mysql'
    else
      'sqlite3'
    end
  end

  def node_version
    if File.exist? '.node_version'
      IO.read('.node_version')[/\d+\.\d+\.\d+/]
    else
      `node --version`[/\d+\.\d+\.\d+/]
    end
  rescue
    "lts" 
  end

  def yarn_version
    package = JSON.parse(IO.read('package.json'))
    if package['packageManager'].to_s.start_with? "yarn@"
      version = package['packageManager'].sub('yarn@', '')
    else
      version = `yarn --version`[/\d+\.\d+\.\d+/]
      system "yarn set version #{version}"

      # apparently not all versions of yarn will update package.json
      package = JSON.parse(IO.read('package.json'))
      unless package['packageManager']
        package['packageManager'] = "yarn@#{version}"
        IO.write('package.json', JSON.pretty_generate(package))
      end
    end

    version
  rescue
    "latest"
  end

  def depend_on_bootsnap?
    @gemfile.include? 'bootsnap'
  end

  def api_only?
    Rails.application.config.api_only
  end

  # scan for node clients.  Do a wide scan if api_only?, otherwise look
  # for specific directories.
  def api_client_dir
    if api_only?
      scan = '*/package.json'
    else
      scan = '{client,frontend}/package.json'
    end

    file = Dir[scan].find do |file|
      JSON.load_file(file).dig('scripts', 'build')
    end

    file && File.dirname(file)
  end

  def api_client_files
    client = api_client_dir
    return unless client

    Dir["#{client}/{package.json,package-lock.json,yarn.lock}"]
  end

  def dbprep_command
    if Rails::VERSION::MAJOR >= 6
      'db:prepare'
    else
      'db:migrate'
    end
  end
end
