class DockerfileGenerator < Rails::Generators::Base
  include DockerfileRails::Scanner

  def generate_app
    source_paths.push File.expand_path('./templates', __dir__)

    scan_rails_app

    template 'Dockerfile.erb', 'Dockerfile'
    template 'dockerignore.erb', '.dockerignore'

    template 'node-version.erb', '.node-version' if using_node?

    template 'docker-entrypoint.erb', 'bin/docker-entrypoint'
    chmod "bin/docker-entrypoint", 0755 & ~File.umask, verbose: false
  end

private
   
  def using_node?
    File.exist? 'package.json'
  end

  def keeps?
    return @keeps if @keeps != nil
    @keeps = !Dir['**/.keep']
  end

  def build_packages
    # start with the essentials
    packages = %w(build-essential)

    # add databases: sqlite3, postgres, mysql
    packages += %w(pkg-config libpq-dev default-libmysqlclient-dev)

    # add redis in case Action Cable, caching, or sidekiq are added later
    packages << "redis"

    # ActiveStorage preview support
    packages << "libvips" if @gemfile.include? 'ruby-vips'

    # node support, including support for building native modules
    if using_node?
      packages += %w(curl node-gyp) # pkg-config already listed above

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

    packages.sort
  end

  def deploy_packages
    # start with databases: sqlite3, postgres, mysql
    packages = %w(libsqlite3-0 postgresql-client default-mysql-client)

    # add redis in case Action Cable, caching, or sidekiq are added later
    packages << "redis"

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

  def node_version
    using_node? and `node --version`[/\d+\.\d+\.\d+/]
  rescue
    "lts" 
  end

  def yarn_version
    using_node? and `yarn --version`[/\d+\.\d+\.\d+/]
  rescue
    "latest"
  end

  def depend_on_bootsnap?
    @gemfile.include? 'bootstrap'
  end

  def api_only?
    Rails.application.config.api_only
  end

  def dbprep_command
    if Rails::VERSION::MAJOR >= 6
      'db:prepare'
    else
      'db:migrate'
    end
  end
end