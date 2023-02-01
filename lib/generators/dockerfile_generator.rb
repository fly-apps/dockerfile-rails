require 'erb'
require_relative '../dockerfile-rails/scanner.rb'

class DockerfileGenerator < Rails::Generators::Base
  include DockerfileRails::Scanner

  OPTION_DEFAULTS = OpenStruct.new(
    'bin-cd' => false,
    'cache' => false,
    'ci' => false,
    'compose' => false,
    'fullstaq' => false,
    'jemalloc' => false,
    'mysql' => false,
    'parallel' => false,
    'platform' => nil,
    'postgresql' => false,
    'prepare' => true,
    'redis' => false,
    'swap' => nil,
    'yjit' => false,
    'label' => {},
  )

  @@labels = {}

  # load defaults from config file
  if File.exist? 'config/dockerfile.yml'
    options = YAML.safe_load_file('config/dockerfile.yml', symbolize_names: true)[:options]

    if options
      OPTION_DEFAULTS.to_h.each do |option, value|
        OPTION_DEFAULTS[option] = options[option] if options.include? option 
      end

      @@labels = options[:label].stringify_keys if options.include? :label
    end
  end

  class_option :ci, type: :boolean, default: OPTION_DEFAULTS.ci,
    desc: 'include test gems in bundle'

  class_option 'bin-cd', type: :boolean, default: OPTION_DEFAULTS['bin-cd'],
    desc: 'modify binstubs to set working directory'

  class_option :cache, type: :boolean, default: OPTION_DEFAULTS.cache,
    desc: 'use build cache to speed up installs'

  class_option :prepare, type: :boolean, default: OPTION_DEFAULTS.prepare,
    desc: 'include db:prepare step'

  class_option :parallel, type: :boolean, default: OPTION_DEFAULTS.parallel,
    desc: 'use build stages to install gems and node modules in parallel'

  class_option :swap, type: :string, default: OPTION_DEFAULTS.swap,
    desc: 'allocate swapspace'

  class_option :compose, type: :boolean, default: OPTION_DEFAULTS.compose,
    desc: 'generate a docker-compose.yml file'

  class_option :redis, type: :boolean, default: OPTION_DEFAULTS.redis,
    desc: 'include redis libraries'

  class_option :sqlite3, aliases: '--sqlite', type: :boolean, default: OPTION_DEFAULTS.sqlite3,
    desc: 'include sqlite3 libraries'

  class_option :postgresql, aliases: '--postgres', type: :boolean, default: OPTION_DEFAULTS.postgresql,
    desc: 'include postgresql libraries'

  class_option :mysql, type: :boolean, default: OPTION_DEFAULTS.mysql,
    desc: 'include mysql libraries'

  class_option :platform, type: :string, default: OPTION_DEFAULTS.platform,
    desc: 'image platform (example: linux/arm64)'

  class_option :jemalloc, type: :boolean, default: OPTION_DEFAULTS.jemalloc,
    desc: 'use jemalloc alternative malloc implementation'
  
  class_option :fullstaq, type: :boolean, default: OPTION_DEFAULTS.fullstaq,
    descr: 'use Fullstaq Ruby image from Quay.io'

  class_option :yjit, type: :boolean, default: OPTION_DEFAULTS.yjit,
    desc: 'enable YJIT optimizing compiler'

  class_option :label, type: :hash, default: {},
    desc: 'Add Docker label(s)'

  def generate_app
    source_paths.push File.expand_path('./templates', __dir__)

    # merge options
    options.label.replace(@@labels.merge(options.label).select {|key, value| value != ''})

    # gather up options for config file
    @dockerfile_config = OPTION_DEFAULTS.dup.to_h.stringify_keys
    options.to_h.each do |option, value|
      @dockerfile_config[option] = value if @dockerfile_config.include? option
    end

    scan_rails_app

    Bundler.with_original_env { install_gems }

    template 'Dockerfile.erb', 'Dockerfile'
    template 'dockerignore.erb', '.dockerignore'

    template 'node-version.erb', '.node-version' if using_node?

    template 'docker-entrypoint.erb', 'bin/docker-entrypoint'
    chmod "bin/docker-entrypoint", 0755 & ~File.umask, verbose: false

    template 'docker-compose.yml.erb', 'docker-compose.yml' if options.compose

    template 'dockerfile.yml.erb', 'config/dockerfile.yml', force: true
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
    options.redis? or @redis or @gemfile.include?('sidekiq')
  end

  def using_execjs?
    @gemfile.include?('execjs') or @gemfile.include?('grover')
  end

  def using_puppeteer?
    @gemfile.include?('grover') or @gemfile.include?('puppeteer-ruby')
  end

  def using_sidekiq?
    @gemfile.include?('sidekiq')
  end

  def parallel?
    using_node? && options.parallel
  end

  def keeps?
    return @keeps if @keeps != nil
    @keeps = !Dir['**/.keep']
  end

  def install_gems
    if options.postgresql? or @postgresql
      system "bundle add pg" unless @gemfile.include? 'pg'
    end

    if options.mysql? or @mysql
      system "bundle add mysql2" unless @gemfile.include? 'mysql2'
    end

    if options.redis? or using_redis?
      system "bundle add redis" unless @gemfile.include? 'redis'
    end
  end

  def base_packages
    packages = []

    if using_execjs?
      packages += %w(curl unzip)
    end

    if using_puppeteer?
      packages += %w(curl gnupg)
    end

    packages.sort.uniq
  end

  def base_requirements
    requirements = []
    requirements << 'nodejs' if using_execjs?
    requirements << 'chrome' if using_puppeteer?
    requirements.join(' and ')
  end

  def build_packages
    # start with the essentials
    packages = %w(build-essential)

    # add databases: sqlite3, postgres, mysql
    packages << 'pkg-config' if options.sqlite3? or @sqlite3
    packages << 'libpq-dev' if options.postgresql? or @postgresql
    packages << 'default-libmysqlclient-dev' if options.mysql? or @mysql

    # add git if needed to install gems
    packages << 'git' if @git

    # add redis if Action Cable, caching, or sidekiq are used
    packages << "redis" if options.redis? or using_redis?

    # ActiveStorage preview support
    packages << "libvips" if @gemfile.include? 'ruby-vips'

    # Rmagick gem
    packages += %w[pkg-config libmagickwand-dev] if @gemfile.include? 'rmagick'

    # node support, including support for building native modules
    if using_node?
      packages += %w(node-gyp pkg-config)
      packages += %w(curl unzip) unless using_execjs? or using_puppeteer?

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
    if @gemfile.include?('rmagick') or @gemfile.include?('mini_magick')
      packages << 'imagemagick'
    end

    # Puppeteer
    packages << 'google-chrome-stable' if using_puppeteer?

    packages.sort
  end

  def deploy_repos
    repos = []

    if using_puppeteer?
      repos += [
       "curl https://dl-ssl.google.com/linux/linux_signing_key.pub |",
       "gpg --dearmor > /etc/apt/trusted.gpg.d/google-archive.gpg &&",
       'echo "deb http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list'
      ]
    end

    if repos.empty?
      ''
    else
      repos.join(" \\\n    ") + " && \\\n    "
    end
  end

  def deploy_env
    env = []

    if Rails::VERSION::MAJOR<7 || Rails::VERSION::STRING.start_with?('7.0')
      env << 'RAILS_LOG_TO_STDOUT="1"'
      env << 'RAILS_SERVE_STATIC_FILES="true"'
    end

    if options.yjit
      env << 'RUBY_YJIT_ENABLE="1"'
    end

    if options.jemalloc and not options.fullstaq
      if (options.platform || Gem::Platform::local.cpu).include? 'arm'
        env << 'LD_PRELOAD="/usr/lib/aarch64-linux-gnu/libjemalloc.so.2"'
      else
        env << 'LD_PRELOAD="/usr/lib/x86_64-linux-gnu/libjemalloc.so.2"'
      end

      env << 'MALLOC_CONF="dirty_decay_ms:1000,narenas:2,background_thread:true"'
    end

    if using_puppeteer?
      env << 'GROVER_NO_SANDBOX="true"' if @gemfile.include? 'grover'
      env << 'PUPPETEER_EXECUTABLE_PATH="/usr/bin/google-chrome"'
    end

    env
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

    # optionally, adjust cwd
    if options['bin-cd']
      binfixups.push %{sed -i '/^#!/aDir.chdir File.expand_path("..", __dir__)' /app/bin/*}
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

    if ENV['RAILS_ENV'] == 'test'
      # yarn install instructions changed in v2
      version = '1.22.19'
    elsif package['packageManager'].to_s.start_with? "yarn@"
      version = package['packageManager'].sub('yarn@', '')
    else
      version = `yarn --version`[/\d+\.\d+\.\d+/] || '1.22.19'
      system "yarn set version #{version}"
      package = JSON.parse(IO.read('package.json'))
      # apparently not all versions of yarn will update package.json...
    end

    unless package['packageManager']
      package['packageManager'] = "yarn@#{version}"
      IO.write('package.json', JSON.pretty_generate(package))
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
