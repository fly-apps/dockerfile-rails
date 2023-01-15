class DockerfileGenerator < Rails::Generators::Base
  include DockerfileRails::Scanner

  class_option :ci, type: :boolean, default: false,
    desc: 'include test gems in bundle'

  class_option :cache, type: :boolean, default: false,
    desc: 'use build cache to speed up installs'

  class_option :parallel, type: :boolean, default: false,
    desc: 'use build stages to install gems and node modules in parallel'

  class_option :compose, type: :boolean, default: false,
    desc: 'generate a docker-compose.yml file'

  class_option :redit, type: :boolean, default: false,
    desc: 'include redis libraries'

  class_option :sqlite3, aliases: '--sqlite', type: :boolean, default: false,
    desc: 'include sqlite3 libraries'

  class_option :postgresql, aliases: '--postgres', type: :boolean, default: false,
    desc: 'include postgresql libraries'

  class_option :mysql, type: :boolean, default: false,
    desc: 'include mysql libraries'

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
   
  def using_node?
    return @using_node if @using_node != nil
    @using_node = File.exist? 'package.json'
  end

  def using_redis?
    options.redis? or @redis
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

    # node support, including support for building native modules
    if using_node?
      packages += %w(curl unzip node-gyp pkg-config)

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
    `node --version`[/\d+\.\d+\.\d+/]
  rescue
    "lts" 
  end

  def yarn_version
    `yarn --version`[/\d+\.\d+\.\d+/]
  rescue
    "latest"
  end

  def depend_on_bootsnap?
    @gemfile.include? 'bootstrap'
  end

  def api_only?
    Rails.application.config.api_only
  end

  def api_client_dir
    return unless api_only?

    file = Dir['*/package.json'].find do |file|
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
