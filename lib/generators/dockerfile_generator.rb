# frozen_string_literal: true

require "erb"
require "json"
require_relative "../dockerfile-rails/scanner.rb"

class DockerfileGenerator < Rails::Generators::Base
  include DockerfileRails::Scanner

  BASE_DEFAULTS = {
    "alpine" => false,
    "bin-cd" => false,
    "cache" => false,
    "ci" => false,
    "compose" => false,
    "fullstaq" => false,
    "gemfile-updates" => true,
    "jemalloc" => false,
    "label" => {},
    "link" => false,
    "litefs" => false,
    "lock" => true,
    "max-idle" => nil,
    "migrate" => "",
    "mysql" => false,
    "nginx" => false,
    "parallel" => false,
    "passenger" => false,
    "platform" => nil,
    "postgresql" => false,
    "precompile" => nil,
    "precompiled-gems" => true,
    "prepare" => true,
    "private-gemserver-domain" => nil,
    "procfile" => "",
    "redis" => false,
    "registry" => "",
    "rollbar" => false,
    "root" => false,
    "sqlite3" => false,
    "sqlserver" => false,
    "sentry" => false,
    "sudo" => false,
    "swap" => nil,
    "tigris" => false,
    "thruster" => false,
    "variant" => nil,
    "windows" => false,
    "yjit" => false,
  }.yield_self { |hash| Struct.new(*hash.keys.map(&:to_sym)).new(*hash.values) }

  OPTION_DEFAULTS = BASE_DEFAULTS.dup

  @@labels = {}
  @@packages = { "base" => [], "build" => [], "deploy" => [] }
  @@vars = { "base" => {}, "build" => {}, "deploy" => {} }
  @@args = { "base" => {}, "build" => {}, "deploy" => {} }
  @@instructions = { "base" => nil, "build" => nil, "deploy" => nil }

  ALPINE_MAPPINGS = {
    "build-essential" => "build-base",
    "chromium-sandbox" => "chromium-chromedriver",
    "default-libmysqlclient-dev" => "mysql-client",
    "default-mysqlclient" => "mysql-client",
    "freedts-bin" => "freedts",
    "libicu-dev" => "icu-dev",
    "libjemalloc" => "jemalloc-dev",
    "libjpeg-dev" => "jpeg-dev",
    "libmagickwand-dev" => "imagemagick-libs",
    "libsqlite3-0" => "sqlite-dev",
    "libtiff-dev" => "tiff-dev",
    "libjemalloc2" => "jemalloc",
    "libvips" => "vips-dev",
    "node-gyp" => "gyp",
    "pkg-config" => "pkgconfig",
    "python" => "python3",
    "python-is-python3" => "python3"
  }

  # load defaults from config file
  if File.exist? "config/dockerfile.yml"
    options = YAML.safe_load(IO.read("config/dockerfile.yml"), symbolize_names: true)[:options]

    if options
      OPTION_DEFAULTS.to_h.each do |option, value|
        OPTION_DEFAULTS[option] = options[option] if options.include? option
      end

      if options[:packages]
        options[:packages].each do |stage, list|
          @@packages[stage.to_s] = list
        end
      end

      if options[:envs]
        options[:envs].each do |stage, vars|
          @@vars[stage.to_s] = vars.stringify_keys
        end
      end

      if options[:args]
        options[:args].each do |stage, vars|
          @@args[stage.to_s] = vars.stringify_keys
        end
      end

      if options[:instructions]
        options[:instructions].each do |stage, value|
          @@instructions[stage.to_s] = value
        end
      end

      @@labels = options[:label].stringify_keys if options.include? :label
    end
  end

  class_option :ci, type: :boolean, default: OPTION_DEFAULTS.ci,
    desc: "include test gems in bundle"

  class_option :link, type: :boolean, default: OPTION_DEFAULTS.link,
    desc: "use COPY --link whenever possible"

  class_option :lock, type: :boolean, default: OPTION_DEFAULTS.lock,
    desc: "lock Gemfile/package.json"

  class_option :precompile, type: :string, default: OPTION_DEFAULTS.precompile,
    desc: 'if set to "defer", assets:precompile will be done at deploy time'

  class_option "precompiled-gems", type: :boolean, default: OPTION_DEFAULTS["precompiled-gems"],
    desc: "use precompiled gems"

  class_option "bin-cd", type: :boolean, default: OPTION_DEFAULTS["bin-cd"],
    desc: "modify binstubs to set working directory"

  class_option "windows", type: :boolean, default: OPTION_DEFAULTS["windows"],
    desc: "fixup CRLF in binstubs and make each executable"

  class_option :cache, type: :boolean, default: OPTION_DEFAULTS.cache,
    desc: "use build cache to speed up installs"

  class_option :prepare, type: :boolean, default: OPTION_DEFAULTS.prepare,
    desc: "include db:prepare step"

  class_option :parallel, type: :boolean, default: OPTION_DEFAULTS.parallel,
    desc: "use build stages to install gems and node modules in parallel"

  class_option :swap, type: :string, default: OPTION_DEFAULTS.swap,
    desc: "allocate swapspace"

  class_option :compose, type: :boolean, default: OPTION_DEFAULTS.compose,
    desc: "generate a docker-compose.yml file"

  class_option :redis, type: :boolean, default: OPTION_DEFAULTS.redis,
    desc: "include redis libraries"

  class_option :sqlite3, aliases: "--sqlite", type: :boolean, default: OPTION_DEFAULTS.sqlite3,
    desc: "include sqlite3 libraries"

  class_option :sqlserver, aliases: "--sqlserver", type: :boolean, default: OPTION_DEFAULTS.sqlserver,
    desc: "include SQL server libraries"

  class_option :litefs, type: :boolean, default: OPTION_DEFAULTS.litefs,
    desc: "replicate sqlite3 databases using litefs"

  class_option :tigris, type: :boolean, default: OPTION_DEFAULTS.tigris,
    desc: "configure active storage to use tigris"

  class_option :postgresql, aliases: "--postgres", type: :boolean, default: OPTION_DEFAULTS.postgresql,
    desc: "include postgresql libraries"

  class_option :mysql, type: :boolean, default: OPTION_DEFAULTS.mysql,
    desc: "include mysql libraries"

  class_option :platform, type: :string, default: OPTION_DEFAULTS.platform,
    desc: "image platform (example: linux/arm64)"

  class_option :registry, type: :string, default: OPTION_DEFAULTS.registry,
    desc: "docker registry to use (example: registry.docker.com/library/)"

  class_option :alpine, type: :boolean, default: OPTION_DEFAULTS.alpine,
    descr: "use alpine image"

  class_option :variant, type: :string, default: OPTION_DEFAULTS.variant,
    desc: "dockerhub image variant (example: slim-bullseye)"

  class_option :jemalloc, type: :boolean, default: OPTION_DEFAULTS.jemalloc,
    desc: "use jemalloc alternative malloc implementation"

  class_option :fullstaq, type: :boolean, default: OPTION_DEFAULTS.fullstaq,
    descr: "use Fullstaq Ruby image from Quay.io"

  class_option :yjit, type: :boolean, default: OPTION_DEFAULTS.yjit,
    desc: "enable YJIT optimizing compiler"

  class_option :label, type: :hash, default: {},
    desc: "Add Docker label(s)"

  class_option :thruster, type: :boolean, default: OPTION_DEFAULTS.thruster,
    desc: "use Thruster HTTP/2 proxy"

  class_option :nginx, type: :boolean, default: OPTION_DEFAULTS.nginx,
    desc: "Serve static files with nginx"

  class_option :passenger, type: :boolean, default: OPTION_DEFAULTS.passenger,
    desc: "Serve Rails application with Phusion Passsenger"

  class_option "max-idle", type: :string, default: OPTION_DEFAULTS["max-idle"],
    desc: "Exit server after application has been idle for n seconds."

  class_option :root, type: :boolean, default: OPTION_DEFAULTS.root,
    desc: "Run application as root user"

  class_option :sudo, type: :boolean, default: OPTION_DEFAULTS.sudo,
    desc: "Install and configure sudo to enable running as rails with full environment"

  class_option :sentry, type: :boolean, default: OPTION_DEFAULTS.sentry,
    desc: "Install gems and a default initializer for Sentry"

  class_option :rollbar, type: :boolean, default: OPTION_DEFAULTS.rollbar,
    desc: "Install gem and a default initializer for Rollbar"

  class_option "migrate", type: :string, default: OPTION_DEFAULTS.migrate,
    desc: "custom migration/db:prepare script"

  class_option "procfile", type: :string, default: OPTION_DEFAULTS.procfile,
    desc: "custom procfile to start services"

  class_option "private-gemserver-domain", type: :string, default: OPTION_DEFAULTS["private-gemserver-domain"],
    desc: "domain name of a private gemserver used when installing application gems"

  class_option "gemfile-updates", type: :boolean, default: OPTION_DEFAULTS["gemfile-updates"],
    desc: "include gemfile updates"

  class_option "add-base", type: :array, default: [],
    desc: "additional packages to install for both build and deploy"

  class_option "add-build", type: :array, default: [],
    desc: "additional packages to install for use during build"

  class_option "add-deploy", aliases: "--add", type: :array, default: [],
    desc: "additional packages to install for deployment"

  class_option "remove-base", type: :array, default: [],
    desc: "remove from list of base packages"

  class_option "remove-build", type: :array, default: [],
    desc: "remove from list of build packages"

  class_option "remove-deploy", aliases: "--remove", type: :array, default: [],
    desc: "remove from list of deploy packages"


  class_option "env-base", type: :hash, default: {},
    desc: "additional environment variables for both build and deploy"

  class_option "env-build", type: :hash, default: {},
    desc: "additional environment variables to set during build"

  class_option "env-deploy", aliases: "--env", type: :hash, default: {},
    desc: "additional environment variables to set for deployment"


  class_option "arg-base", aliases: "--arg", type: :hash, default: {},
    desc: "additional build arguments for both build and deploy"

  class_option "arg-build", type: :hash, default: {},
    desc: "additional build arguments to set during build"

  class_option "arg-deploy", type: :hash, default: {},
    desc: "additional build arguments to set for deployment"


  class_option "instructions-base", type: :string, default: "",
    desc: "additional instructions to add to the base stage"

  class_option "instructions-build", type: :string, default: "",
    desc: "additional instructions to add to the build stage"

  class_option "instructions-deploy", aliases: "--instructions", type: :string, default: "",
    desc: "additional instructions to add to the final stage"


  def generate_app
    source_paths.push File.expand_path("./templates", __dir__)

    # merge options
    options.label.replace(@@labels.merge(options.label).select { |key, value| value != "" })

    # gather up options for config file
    @dockerfile_config = OPTION_DEFAULTS.dup.to_h.stringify_keys
    options.to_h.each do |option, value|
      @dockerfile_config[option] = value if @dockerfile_config.include? option
    end

    %w(base build deploy).each do |phase|
      @@packages[phase] += options["add-#{phase}"]
      @@packages[phase] -= options["remove-#{phase}"]
      @@packages[phase].uniq!
      @@packages.delete phase if @@packages[phase].empty?

      @@vars[phase].merge! options["env-#{phase}"]
      @@vars[phase].delete_if { |key, value| value.blank? }
      @@vars.delete phase if @@vars[phase].empty?

      @@args[phase].merge! options["arg-#{phase}"]
      @@args[phase].delete_if { |key, value| value.blank? }
      @@args.delete phase if @@args[phase].empty?

      @@instructions[phase] ||= options["instructions-#{phase}"]
      @@instructions.delete phase if @@instructions[phase].empty?
    end

    @dockerfile_config["packages"] = @@packages
    @dockerfile_config["envs"] = @@vars
    @dockerfile_config["args"] = @@args
    @dockerfile_config["instructions"] = @@instructions

    scan_rails_app

    Bundler.with_original_env { install_gems }

    template "Dockerfile.erb", "Dockerfile"
    template "dockerignore.erb", ".dockerignore"

    if using_node? && node_version =~ (/\A\d+\.\d+\.\d+\z/)
      template "node-version.erb", ".node-version"
    end

    template "docker-entrypoint.erb", "bin/docker-entrypoint"
    chmod "bin/docker-entrypoint", 0755 & ~File.umask, verbose: false

    template "docker-compose.yml.erb", "docker-compose.yml" if options.compose

    if fix_database_config
      template "database.yml.erb", "config/database.yml",
        force: File.exist?("fly.toml")
    end

    if using_litefs?
      template "litefs.yml.erb", "config/litefs.yml"

      fly_attach_consul
    end

    if File.exist?("fly.toml") && (fly_processes || !options.prepare || options.swap || deploy_database == "sqlite3")
      if File.stat("fly.toml").size > 0
        template "fly.toml.erb", "fly.toml"
      else
        toml = fly_make_toml
        File.write "fly.toml", toml if toml != ""
      end
    end

    if options.sentry? && (not File.exist?("config/initializers/sentry.rb"))
      template "sentry.rb.erb", "config/initializers/sentry.rb"
    end

    if options.rollbar? && (not File.exist?("config/initializers/rollbar.rb"))
      template "rollbar.rb.erb", "config/initializers/rollbar.rb"
    end

    if @gemfile.include?("vite_ruby")
      package = JSON.load_file("package.json")
      unless package.dig("scripts", "build")
        package["scripts"] ||= {}
        package["scripts"]["build"] = "vite build --outDir public"

        say_status :update, "package.json"
        IO.write("package.json", JSON.pretty_generate(package))
      end
    end

    @dockerfile_config = (@dockerfile_config.to_a - BASE_DEFAULTS.to_h.stringify_keys.to_a).to_h
    %w(packages envs args instructions).each do |key|
      @dockerfile_config.delete key if @dockerfile_config[key].empty?
    end

    if !@dockerfile_config.empty?
      template "dockerfile.yml.erb", "config/dockerfile.yml", force: true
    elsif File.exist? "config/dockerfile.yml"
      remove_file "config/dockerfile.yml"
    end

    if options.tigris?
      configure_tigris
    end

    # check Dockerfile for common errors: missing packages, mismatched Ruby version;
    # also add DATABASE_URL to fly.toml if needed
    if options.skip? && File.exist?("Dockerfile")
      message = nil
      shell = Thor::Base.shell.new

      dockerfile = IO.read("Dockerfile")
      missing = Set.new(base_packages + build_packages) -
        Set.new(dockerfile.scan(/[-\w]+/))

      unless missing.empty?
        message = "The following packages are missing from the Dockerfile: #{missing.to_a.join(", ")}"
        STDERR.puts "\n" + shell.set_color(message, Thor::Shell::Color::RED, Thor::Shell::Color::BOLD)
      end

      ruby_version = dockerfile.match(/ARG RUBY_VERSION=(\d+\.\d+\.\d+)/)[1]

      if ruby_version && ruby_version != RUBY_VERSION
        message = "The Ruby version in the Dockerfile (#{ruby_version}) does not match the Ruby version of the Rails app (#{RUBY_VERSION})"
        STDERR.puts "\n" + shell.set_color(message, Thor::Shell::Color::RED, Thor::Shell::Color::BOLD)
      end

      if @netpopbug && !dockerfile.include?("net-pop")
        message = "Ruby 3.3.3 net-pop bug detected."
        STDERR.puts "\n" + shell.set_color(message, Thor::Shell::Color::RED, Thor::Shell::Color::BOLD)
        STDERR.puts "Please see https://github.com/ruby/ruby/pull/11006"
        STDERR.puts "Change your Ruby version, or run `bin/rails generate dockerfile`,"
        STDERR.puts "or add the following to your Dockerfile:"
        STDERR.puts 'RUN sed -i "/net-pop (0.1.2)/a\      net-protocol" Gemfile.lock'
      end

      if File.exist?("fly.toml")
        env = {}

        if (options.sqlite3? || @sqlite3) && !dockerfile.include?("DATABASE_URL")
          env["DATABASE_URL"] = "sqlite3:///data/production.sqlite3"
        end

        if using_thruster? && !dockerfile.include?("HTTP_PORT")
          env["HTTP_PORT"] = "8080"
        end

        unless env.empty?
          toml = IO.read("fly.toml")
          if !toml.include?("[[env]]")
            toml += "\n[[env]]\n" + env.map { |key, value| "  #{key} = #{value.inspect}" }.join("\n")
            File.write "fly.toml", toml
          end
        end
      end

      exit 42 if message
    end
  end

private
  def render(options)
    scope = (Class.new do
      def initialize(obj, locals)
        @_obj = obj
        @_locals = locals.yield_self do |hash|
          return nil if hash.empty?
          Struct.new(*hash.keys.map(&:to_sym)).new(*hash.values)
        end
      end

      def method_missing(method, *args, &block)
        if @_locals&.respond_to? method
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
    ERB.new(template, trim_mode: "-").result(scope.get_binding).strip
  end

  def platform
    if options.platform
      "--platform=#{options.platform} "
    else
      ""
    end
  end

  def variant
    options.variant || (options.alpine ? "alpine" : "slim")
  end

  def run_as_root?
    options.root?
  end

  def using_litefs?
    options.litefs?
  end

  def using_litestack?
    @gemfile.include?("litestack")
  end

  def using_node?
    return @using_node if @using_node != nil
    return if using_bun?
    @using_node = File.exist?("package.json")
  end

  def using_bun?
    return @using_bun if @using_bun != nil
    @using_bun = File.exist?("bun.config.js") || File.exist?("bun.lockb")
  end

  def references_ruby_version_file?
    @references_ruby_version_file ||= IO.read("Gemfile").include?(".ruby-version")
  end

  def using_redis?
    # Note: If you have redis installed on your computer, 'rails new` will
    # automatically add redis to your Gemfile, so having it in your Gemfile is
    # not a reliable indicator of whether or not your application actually uses
    # redis.

    # using_redis? is currently used for two things: actually adding the redis
    # gem if it is going to be needed in production, and adding a redis
    # container to docker-compose.yml. Neither of these actions should be done
    # unless there is an indication that redis is actually being used and not
    # merely included in the Gemfile.

    options.redis? or @redis or @gemfile.include?("sidekiq")
  end

  def using_execjs?
    @gemfile.include?("execjs") or @gemfile.include?("grover")
  end

  def using_puppeteer?
    @gemfile.include?("grover") or @gemfile.include?("puppeteer-ruby")
  end

  def using_passenger?
    options.passenger? or options["max-idle"]
  end

  def includes_jobs?
    !(Dir["app/jobs/*.rb"] - ["app/jobs/application_job.rb"]).empty?
  end

  def using_sidekiq?
    @gemfile.include?("sidekiq")
  end

  def using_solidq?
    @gemfile.include?("solid_queue") and includes_jobs?
  end

  def parallel?
    (using_node? || using_bun?) && options.parallel
  end

  def has_mysql_gem?
    @gemfile.include? "mysql2" or using_trilogy?
  end

  def using_trilogy?
    @gemfile.include?("trilogy") || @gemfile.include?("activerecord-trilogy-adapter")
  end

  def keeps?
    return @keeps if @keeps != nil
    @keeps = !!Dir["**/.keep"]
  end

  def install_gems
    return unless options["gemfile-updates"]

    ENV["BUNDLE_IGNORE_MESSAGES"] = "1"

    gemfile = IO.read("Gemfile")

    unless /^\s*source\s/.match?(gemfile)
      gemfile = %{source "https://rubygems.org"\n} + gemfile
    end

    if options.postgresql? || @postgresql
      system "bundle add pg --skip-install" unless @gemfile.include? "pg"
    end

    if options.mysql? || @mysql
      system "bundle add mysql2 --skip-install" unless has_mysql_gem?
    end

    if options.redis? || using_redis?
      system "bundle add redis --skip-install" unless @gemfile.include? "redis"
    end

    if options.tigris?
      system "bundle add aws-sdk-s3 --require=false --skip-install" unless @gemfile.include? "aws-sdk-s3"
    end

    if options.sentry?
      system "bundle add sentry-ruby --skip-install" unless @gemfile.include? "sentry-ruby"
      system "bundle add sentry-rails --skip-install" unless @gemfile.include? "sentry-rails"
    end

    if options.thruster?
      system "bundle add thruster --skip-install" unless @gemfile.include? "thruster"
    end

    if options.rollbar?
      system "bundle add rollbar --skip-install" unless @gemfile.include? "rollbar"
    end

    # https://stackoverflow.com/questions/70500220/rails-7-ruby-3-1-loaderror-cannot-load-such-file-net-smtp/70500221#70500221
    if @gemfile.include? "mail"
      %w(net-smtp net-imap net-pop).each do |gem|
        system "bundle add #{gem} --skip-install --require false" unless @gemfile.include? gem
      end
    end

    unless gemfile == IO.read("Gemfile")
      system "bundle install --quiet"
    end

    if options.lock?
      # ensure linux platform is in the bundle lock
      current_platforms = `bundle platform`
      add_platforms = []

      if !current_platforms.include?("x86_64-linux")
        add_platforms += ["--add-platform=x86_64-linux"]
      end

      if !current_platforms.include?("aarch64-linux") && RUBY_PLATFORM.start_with?("arm64")
        add_platforms += ["--add-platform=aarch64-linux"]
      end

      unless add_platforms.empty?
        system "bundle lock #{add_platforms.join(" ")}"
      end
    end
  end

  def base_gems
    gems = ["bundler"]

    if options.ci? && options.lock? && @gemfile.include?("debug")
      # https://github.com/rails/rails/pull/47515
      # https://github.com/rubygems/rubygems/issues/6082#issuecomment-1329756343
      gems += %w(irb reline) - @gemfile unless Gem.ruby_version >= Gem::Version.new("3.2.2")
    end

    gems.sort
  end

  def alpinize(packages)
    packages.map { |package| ALPINE_MAPPINGS[package] || package }.sort.uniq
  end

  def base_packages
    packages = []
    packages += @@packages["base"] if @@packages["base"]

    if using_execjs?
      if node_version == "lts"
        packages += %w(nodejs npm)
      else
        packages += %w(curl)
      end
    end

    if using_puppeteer?
      packages += %w(curl gnupg)
    end

    # charlock_holmes.  Placed here as the library itself is
    # libicu63 in buster, libicu67 in bullseye, libiclu72 in bookworm...
    packages << "libicu-dev" if @gemfile.include? "charlock_holmes"

    if @gemfile.include? "webp-ffi"
      # https://github.com/le0pard/webp-ffi#requirements
      packages += %w(libjpeg-dev libpng-dev libtiff-dev libwebp-dev)
    end

    # Passenger
    packages << "passenger" if using_passenger?

    if options.alpine?
      packages << "tzdata"

      alpinize(packages)
    else
      packages.sort.uniq
    end
  end

  def base_requirements
    requirements = []
    requirements << "nodejs" if using_execjs?
    requirements << "chrome" if using_puppeteer?
    requirements << "charlock_holmes" if @gemfile.include? "charlock_holmes"
    requirements.join(" and ")
  end

  def build_packages
    # start with the essentials
    packages = %w(build-essential)
    packages += @@packages["build"] if @@packages["build"]
    packages += %w(nodejs npm) if (node_version == "lts") && (not using_execjs?)
    packages << "libyaml-dev" if options.fullstaq?

    # add databases: sqlite3, postgres, mysql
    packages << "pkg-config" if options.sqlite3? || @sqlite3
    packages << "libpq-dev" if options.postgresql? || @postgresql
    packages << "freetds-dev" if options.sqlserver? || @sqlserver

    if (options.mysql? || @mysql) && !using_trilogy?
      packages << "default-libmysqlclient-dev"
    end

    # add git if needed to install gems
    packages << "git" if @git

    # ActiveStorage preview support
    packages << "libvips" if @gemfile.include? "ruby-vips"

    # Rmagick gem
    packages += %w[pkg-config libmagickwand-dev] if @gemfile.include? "rmagick"

    # node support, including support for building native modules
    if using_node?
      packages += %w(node-gyp pkg-config)

      unless using_execjs? || using_puppeteer?
        packages << "curl"
      end

      # module build process depends on Python, and debian changed
      # how python is installed with the bullseye release.  Below
      # is based on debian release included with the Ruby images on
      # Dockerhub.
      case RUBY_VERSION
      when /^2\.7/
        bullseye = RUBY_VERSION >= "2.7.4"
      when /^3\.0/
        bullseye = RUBY_VERSION >= "3.0.2"
      when /^2\./
        bullseye = false
      else
        bullseye = true
      end

      if bullseye
        packages << "python-is-python3"
      else
        packages << "python"
      end
    end

    if using_bun?
      packages += %w(curl unzip)
    end

    if options.alpine?
      alpinize(packages)
    else
      packages.sort.uniq
    end
  end

  def deploy_packages
    packages = %w(curl) # work with the default healthcheck strategy in MRSK
    packages += @@packages["deploy"] if @@packages["deploy"]

    # start with databases: sqlite3, postgres, mysql
    packages << "postgresql-client" if options.postgresql? || @postgresql
    packages << "default-mysql-client" if options.mysql? || @mysql
    packages << "freetds-bin" if options.sqlserver? || @sqlserver
    packages << "libjemalloc2" if options.jemalloc? && !options.fullstaq?
    if options.sqlite3? || @sqlite3
      packages << "libsqlite3-0" unless packages.include? "sqlite3"
    end

    # litefs
    packages += ["ca-certificates", "fuse3", "sudo"] if options.litefs?

    # ActiveStorage preview support
    packages << "libvips" if @gemfile.include? "ruby-vips"

    # Rmagick gem
    if @gemfile.include?("rmagick") || @gemfile.include?("mini_magick")
      packages << "imagemagick"
    end

    # Puppeteer
    if using_puppeteer?
      if options.platform&.include? "amd"
        packages << "google-chrome-stable"
      else
        packages += %w(chromium chromium-sandbox)
      end
    end

    # Passenger
    packages << "libnginx-mod-http-passenger" if using_passenger?

    # nginx
    packages << "nginx" if options.nginx? || using_passenger?

    # sudo
    packages << "sudo" if options.sudo?

    if !options.procfile.blank? || (procfile.size > 1)
      packages << "ruby-foreman"
    end

    if options.alpine?
      packages << "sqlite-libs" if @gemfile.include? "sqlite3"
      packages << "libpq" if @gemfile.include? "pg"

      alpinize(packages)
    else
      packages.sort.uniq
    end
  end

  def pkg_update
    if options.alpine?
      "apk update"
    else
      "apt-get update -qq"
    end
  end

  def pkg_install
    if options.alpine?
      "apk add"
    else
      "apt-get install --no-install-recommends -y"
    end
  end

  def pkg_cache
    if options.alpine?
      { "dev-apk-cache" => "/var/cache/apk" }
    else
      { "dev-apt-cache" => "/var/cache/apt", "dev-apt-lib" => "/var/lib/apt" }
    end
  end

  def pkg_cleanup
    if options.alpine?
      "/var/cache/apk/*"
    else
      "/var/lib/apt/lists /var/cache/apt/archives"
    end
  end

  def base_repos
    repos = []
    packages = []

    if using_passenger?
      packages += %w(gnupg curl)
      repos += [
       "curl https://oss-binaries.phusionpassenger.com/auto-software-signing-gpg-key.txt |",
       "  gpg --dearmor > /etc/apt/trusted.gpg.d/phusion.gpg &&",
       "bash -c 'echo deb https://oss-binaries.phusionpassenger.com/apt/passenger $(source /etc/os-release; echo $VERSION_CODENAME) main > /etc/apt/sources.list.d/passenger.list'"
      ]
    end

    if repos.empty?
      ""
    else
      packages.sort!.uniq!
      unless packages.empty?
        repos.unshift "#{pkg_update} &&",
          "#{pkg_install} #{packages.join(" ")} &&"
      end

      repos.join(" \\\n    ") + " && \\\n    "
    end
  end

  def deploy_repos
    repos = []
    packages = []

    if using_puppeteer? && deploy_packages.include?("google-chrome-stable")
      packages += %w(gnupg curl)
      repos += [
       "curl https://dl-ssl.google.com/linux/linux_signing_key.pub |",
       "  gpg --dearmor > /etc/apt/trusted.gpg.d/google-archive.gpg &&",
       'echo "deb http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list'
      ]
    end

    if repos.empty?
      ""
    else
      packages.sort!.uniq!
      unless packages.empty?
        repos.unshift "#{pkg_update} &&",
          "#{pkg_install} --no-install-recommends -y #{packages.join(" ")} &&"
      end

      repos.join(" \\\n    ") + " && \\\n    "
    end
  end

  def base_env
    env = {
      "RAILS_ENV" => "production",
      "BUNDLE_PATH" => "/usr/local/bundle",
      "BUNDLE_WITHOUT" => options.ci? ? "development" : "development:test"
    }

    if options.lock?
      env["BUNDLE_DEPLOYMENT"] = "1"
    end

    if using_litestack?
      env["LITESTACK_DATA_PATH"] = "/data"
    end

    if @@args["base"]
      env.merge! @@args["base"].to_h { |key, value| [key, "$#{key}"] }
    end

    env.merge! @@vars["base"] if @@vars["base"]

    env.map { |key, value| "#{key}=#{value.inspect}" }.sort
  end

  def build_env
    env = {}

    if using_execjs? && (node_version != "lts")
      env["PATH"] = "/usr/local/node/bin:$PATH"
    end

    if using_puppeteer?
      env["PUPPETEER_SKIP_CHROMIUM_DOWNLOAD"] = "true"
    end

    if @@args["build"]
      env.merge! @@args["build"].to_h { |key, value| [key, "$#{key}"] }
    end

    env.merge! @@vars["build"] if @@vars["build"]

    env.map { |key, value| "#{key}=#{value.inspect}" }
  end

  def deploy_env
    env = {}

    env["PORT"] = "3001" if (options.nginx? && !using_passenger?) || using_litefs?

    if Rails::VERSION::MAJOR < 7 || Rails::VERSION::STRING.start_with?("7.0")
      env["RAILS_LOG_TO_STDOUT"] = "1"
      env["RAILS_SERVE_STATIC_FILES"] = "true" unless options.nginx?
    end

    if deploy_database == "sqlite3"
      if using_litefs?
        env["DATABASE_URL"] = "sqlite3:///litefs/production.sqlite3"
      else
        env["DATABASE_URL"] = "sqlite3:///data/production.sqlite3"
      end
    end

    if options.yjit?
      env["RUBY_YJIT_ENABLE"] = "1"
    end

    if options.jemalloc? && !options.fullstaq?
      env["LD_PRELOAD"] = "libjemalloc.so.2"
      env["MALLOC_CONF"] = "dirty_decay_ms:1000,narenas:2,background_thread:true"
    end

    if using_puppeteer?
      env["GROVER_NO_SANDBOX"] = "true" if @gemfile.include? "grover"
      env["PUPPETEER_RUBY_NO_SANDBOX"] = "1"  if @gemfile.include? "puppeteer-ruby"

      if options.platform&.include? "amd"
        env["PUPPETEER_EXECUTABLE_PATH"] = "/usr/bin/google-chrome"
      else
        env["PUPPETEER_EXECUTABLE_PATH"] = "/usr/bin/chromium"
      end
    end

    if @@args["deploy"]
      env.merge! @@args["deploy"].to_h { |key, value| [key, "$#{key}"] }
    end

    env.merge! @@vars["deploy"] if @@vars["deploy"]

    env.map { |key, value| "#{key}=#{value.inspect}" }.sort
  end

  def base_args
    args = {}

    args.merge! @@args["base"] if @@args["base"]

    args
  end

  def build_args
    args = {}

    args.merge! @@args["build"] if @@args["build"]

    args
  end

  def deploy_args
    args = {}

    args.merge! @@args["deploy"] if @@args["deploy"]

    args
  end

  def all_args
    args = {}

    unless options.root?
      args[:UID] = "${UID:-1000}".html_safe
      args[:GID] = "${GID:-${UID:-1000}}".html_safe
    end

    args.merge! base_args
    args.merge! build_args
    args.merge! deploy_args

    args
  end

  def base_instructions
    return nil unless @@instructions["base"]

    instructions = IO.read @@instructions["base"]

    if instructions.start_with? "#!"
      instructions = "# custom instructions\nRUN #{@@instructions["base"].strip}"
    end

    instructions.html_safe
  end

  def build_instructions
    return nil unless @@instructions["build"]

    instructions = IO.read @@instructions["build"]

    if instructions.start_with? "#!"
      instructions = "# custom build instructions\nRUN #{@@instructions["build"].strip}"
    end

    instructions.html_safe
  end

  def deploy_instructions
    return nil unless @@instructions["deploy"]

    instructions = IO.read @@instructions["deploy"]

    if instructions.start_with? "#!"
      instructions = "# custom deploy instructions\nRUN #{@@instructions["deploy"].strip}"
    end

    instructions.html_safe
  end

  def binfile_fixups
    binfiles = Dir["bin/*"].select { |f| File.file?(f) }
    # binfiles may have OS specific paths to ruby.  Normalize them.
    shebangs = binfiles.map do |file|
      IO.read(file).lines.first.encode("UTF-8", "binary", invalid: :replace, undef: :replace, replace: "")
    end.join
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
    has_cr = binfiles.any? { |file| IO.read(file).include? "\r" }
    if has_cr || (Gem.win_platform? && !binfixups.empty?) || options.windows?
      binfixups.unshift 'sed -i "s/\r$//g" bin/*'
    end

    # Windows file systems may not have the concept of executable.
    # In such cases, fix up during the build.
    if binfiles.any? { |file| !File.executable?(file) } || options.windows?
      binfixups.unshift "chmod +x bin/*"
    end

    # optionally, adjust cwd
    if options["bin-cd"]
      binfixups.push %{grep -l '#!/usr/bin/env ruby' /rails/bin/* | xargs sed -i '/^#!/aDir.chdir File.expand_path("..", __dir__)'}
    end

    binfixups
  end

  def deploy_database
    # note: as database can be overridden at runtime via DATABASE_URL,
    # use presence of "pg" or "mysql2" in the bundle as evidence of intent.
    if options.postgresql? || @postgresql || @gemfile.include?("pg")
      "postgresql"
    elsif options.mysql? || @mysql || has_mysql_gem?
      "mysql"
    elsif options.sqlserver || @sqlserver
      "sqlserver"
    else
      "sqlite3"
    end
  end

  def node_version
    return unless using_node? || using_execjs?

    version = nil

    if File.exist? ".node-version"
      version = IO.read(".node-version")[/\d+\.\d+\.\d+/]
    end

    if !version && File.exist?("package.json")
      version = JSON.parse(IO.read("package.json")).dig("engines", "node")
      version = nil unless /\A(\d+\.)+(\d+|x)\z/.match?(version)
    end

    version || `node --version`[/\d+\.\d+\.\d+/]
  rescue
    "lts"
  end

  def yarn_version
    package = JSON.parse(IO.read("package.json"))

    if ENV["RAILS_ENV"] == "test"
      # yarn install instructions changed in v2
      version = "1.22.19"
    elsif package["packageManager"].to_s.start_with? "yarn@"
      version = package["packageManager"].sub("yarn@", "")
    else
      version = `yarn --version`[/\d+\.\d+\.\d+/] || "1.22.19"
      system "yarn set version #{version}"
      package = JSON.parse(IO.read("package.json"))
      # apparently not all versions of yarn will update package.json...
    end

    unless package["packageManager"]
      package["packageManager"] = "yarn@#{version}"
      IO.write("package.json", JSON.pretty_generate(package))
    end

    version
  rescue
    "1.22.19"
  end


  def bun_version
    version = `bun --version`[/\d+\.\d+\.\d+/] rescue nil
    version ||= `npm show bun version`[/\d+\.\d+\.\d+/] rescue nil

    version
  end

  def depend_on_bootsnap?
    @gemfile.include? "bootsnap"
  end

  def api_only?
    Rails.application.config.api_only
  end

  # scan for node clients.  Do a wide scan if api_only?, otherwise look
  # for specific directories.
  def api_client_dir
    if api_only?
      scan = "*/package.json"
    else
      scan = "{client,frontend}/package.json"
    end

    file = Dir[scan].find do |file|
      JSON.load_file(file).dig("scripts", "build")
    end

    file && File.dirname(file)
  end

  def api_client_files
    client = api_client_dir
    return unless client

    Dir["#{client}/{package.json,package-lock.json,yarn.lock,bun.lockb}"]
  end

  def dbprep_command
    if !options.migrate.blank?
      options.migrate
    elsif Rails::VERSION::MAJOR >= 6
      "./bin/rails db:prepare"
    else
      "./bin/rails db:migrate"
    end
  end

  def procfile
    if using_passenger?
      {
        nginx: "nginx"
      }
    elsif options.nginx?
      {
        nginx: '/usr/sbin/nginx -g "daemon off;"',
        rails: "./bin/rails server -p 3001"
      }
    elsif using_thruster?
      {
        rails: "bundle exec thrust ./bin/rails server"
      }
    else
      {
        rails: "./bin/rails server"
      }
    end
  end

  def using_thruster?
    options.thruster? || @gemfile.include?("thruster")
  end

  def fly_processes
    return unless File.exist? "fly.toml"
    return unless using_sidekiq? || using_solidq?

    if procfile.size > 1
      list = { "app" => "foreman start --procfile=Procfile.prod" }
    else
      list = { "app" => procfile.values.first }
    end

    if using_sidekiq?
      list["sidekiq"] = "bundle exec sidekiq"
    elsif using_solidq?
      list["solidq"] = "bundle exec rake solid_queue:start"
    end

    list
  end

  def more_docker_ignores
    more = ""

    if @gemfile.include?("vite_ruby")
      lines = IO.read(".gitignore")[/^# Vite.*?\n\n/m].to_s.chomp.lines -
         ["node_modules\n"]

      more += "\n" + lines.join
    end

    # Ignore files uploaded using Shrine in development. This is the location used in their documentation.
    # https://shrinerb.com/docs/getting-started
    if @gemfile.include?("shrine")
      more += "\n/public/uploads/*\n"
    end

    more
  end

  def compose_web_volumes
    volumes = %w[ log storage ]

    if deploy_database == "sqlite3"
      database = YAML.load_file("config/database.yml", aliases: true).dig("production", "database")
      if database && database =~ /^\w/
        volumes << File.dirname(database)
      end
    end

    volumes.uniq.sort
  end

  def max_idle
    option = options["max-idle"]

    if option == nil || option.strip.downcase == "infinity"
      nil
    elsif /^\s*\d+(\.\d+)\s*/.match? option
      option.to_f
    elsif /^\s*P/.match? option
      ActiveSupport::Duration.parse(option.strip).seconds
    else
      option.scan(/\d+\w/).map do |t|
        ActiveSupport::Duration.parse("PT#{t.upcase}") rescue ActiveSupport::Duration.parse("P#{t.upcase}")
      end.sum.seconds
    end
  rescue ArgumentError
    nil
  end

  # Takes the domain of the private gemserver and returns the name of the
  # environment variable, as expected by bundler.
  #
  # For example, if the domain is "gems.example.com", the environment variable
  # name will be "BUNDLE_GEMS__EXAMPLE__COM".
  def private_gemserver_env_variable_name
    option = options["private-gemserver-domain"]

    return nil if option.blank?

    "BUNDLE_#{option.upcase.gsub(".", "__")}"
  end

  # if running on fly v2, make a best effort to attach consul
  def fly_attach_consul
    # certainly not fly unless there is a fly.toml
    return unless File.exist? "fly.toml"

    # Check fly.toml to guess if v1 or v2
    toml = File.read("fly.toml")
    return if toml.include?("enable_consul") # v1-ism
    return unless toml.include?("primary_region") # v2

    # see if flyctl is in the path
    flyctl = (lambda do
      cmd = "flyctl"
      ENV["PATH"].split(File::PATH_SEPARATOR).each do |path|
        (ENV["PATHEXT"] ? ENV["PATHEXT"].split(";") : [""]).each do |ext|
          path = File.join(path, "#{cmd}#{ext}")
          return path if File.executable? path
        end
      end

      nil
    end).call
    return unless flyctl

    # see if secret is already set?
    begin
      secrets = JSON.parse(`#{flyctl} secrets list --json`)
      return if secrets.any? { |secret| secret["Name"] == "FLY_CONSUL_URL" }
    rescue
      return # likely got an error like "Could not find App"
    end

    # attach consul
    say_status :execute, "flyctl consul attach", :green
    system "#{flyctl} consul attach"
  end

  def configure_tigris
    return unless options.tigris?

    service = [
      "tigris:",
      "  service: S3",
      '  access_key_id: <%= ENV["AWS_ACCESS_KEY_ID"] %>',
      '  secret_access_key: <%= ENV["AWS_SECRET_ACCESS_KEY"] %>',
      '  endpoint: <%= ENV["AWS_ENDPOINT_URL_S3"] %>',
      '  bucket: <%= ENV["BUCKET_NAME"] %>'
    ]

    shell = Thor::Base.shell.new

    if File.exist?("config/storage.yml")
      storage = IO.read("config/storage.yml")
      if storage.include? "tigris"
        STDOUT.puts shell.set_color("unchanged".rjust(12), Thor::Shell::Color::BLUE, Thor::Shell::Color::BOLD) +
          "  config/storage.yml"
      else
        storage = storage.strip + "\n\n" + service.join("\n") + "\n"
        IO.write("config/storage.yml", storage)
        STDOUT.puts shell.set_color("updated".rjust(12), Thor::Shell::Color::GREEN, Thor::Shell::Color::BOLD) +
          "  config/storage.yml"
      end
    end

    if File.exist?("config/environments/production.rb")
      production = IO.read("config/environments/production.rb")
      if !production.include?("tigris") && production.include?("config.active_storage.service")
        production.sub!(/config.active_storage.service.*/, "config.active_storage.service = :tigris")
        production.sub! "# Store uploaded files on the local file system",
          "# Store uploaded files in Tigris Global Object Storage"
        IO.write("config/environments/production.rb", production)
        STDOUT.puts shell.set_color("updated".rjust(12), Thor::Shell::Color::GREEN, Thor::Shell::Color::BOLD) +
          "  config/environments/production.rb"
      else
        STDOUT.puts shell.set_color("unchanged".rjust(12), Thor::Shell::Color::BLUE, Thor::Shell::Color::BOLD) +
          "  config/environments/production.yml"
      end
    end
  end

  def fly_make_toml
    toml = File.read("fly.toml")

    list = fly_processes
    if list
      if toml.include? "[processes]"
        toml.sub!(/\[processes\].*?(\n\n|\n?\z)/m, "[processes]\n" +
          list.map { |name, cmd| "  #{name} = #{cmd.inspect}" }.join("\n") + '\1')
      else
        toml += "\n[processes]\n" +
          list.map { |name, cmd| "  #{name} = #{cmd.inspect}\n" }.join + "\n"

        app = list.has_key?("app") ? "app" : list.keys.first

        toml.sub! "[http_service]\n", "\\0  processes = [#{app.inspect}]\n"
      end
    end

    if options.prepare == false
      deploy = "[deploy]\n  release_command = #{dbprep_command.inspect}\n\n"
      if toml.include? "[deploy]"
        toml.sub!(/\[deploy\].*?(\n\n|\n?\z)/m, deploy)
      else
        toml += deploy
      end
    end

    if deploy_database == "sqlite3"
      if not toml.include? "[mounts]"
        toml += "[mounts]\n  source=\"data\"\n  destination=\"/data\"\n\n"
      end
    end

    if options.swap
      suffixes = {
        "kib" => 1024,
        "k"   => 1024,
        "kb"  => 1000,
        "mib" => 1048576,
        "m"   => 1048576,
        "mb"  => 1000000,
        "gib" => 1073741824,
        "g"   => 1073741824,
        "gb"  => 1000000000,
      }

      pattern = Regexp.new("^(\\d+)(#{suffixes.keys.join('|')})?$", "i")

      match = pattern.match(options.swap.downcase)

      if match
        size = ((match[1].to_i * (suffixes[match[2]] || 1)) / 1048576.0).round
        if toml.include? "swap_size_mb"
          toml.sub!(/swap_size_mb.*/, "swap_size_mb = #{size}")
        else
          toml += "swap_size_mb = #{size}\n\n"
        end
      end
    end

    # Add statics if not already present and not using a web server and workdir doesn't contain a variable
    unless options.nginx? || using_passenger? || options.thruster? || @gemfile.include?("thruster")
      workdir = (IO.read "Dockerfile" rescue "").scan(/^\s*WORKDIR\s+(\S+)/).flatten.last
      unless workdir && !workdir.include?("$") && toml.include?("[statics]")
        toml += "[[statics]]\n  guest_path = \"#{workdir}/public\"\n  url_prefix = \"/\"\n\n"
      end
    end

    toml
  end

  # if there are multiple production databases defined, allow them all to be
  # configured via DATABASE_URL.
  def fix_database_config
    yaml = IO.read("config/database.yml")

    production = YAML.load(yaml, aliases: true)["production"]
    return unless production.is_a?(Hash) && production.values.all?(Hash)
    return if production.keys == [ "primary" ]

    section = yaml[/^(production:.*?)(^\S|\z)/m, 1]

    replacement = section.gsub(/(  ).*?\n((\1\s+).*?\n)*/) do |subsection|
      spaces = $3
      name = subsection[/\w+/]

      if /^ +url:/.match?(subsection)
        subsection
      elsif name == "primary"
        subsection + spaces + %(url: <%= ENV["DATABASE_URL"] %>\n)
      else
        subsection + spaces + %(url: <%= URI.parse(ENV["DATABASE_URL"]).tap { |url| url.path += "_#{name}" } if ENV["DATABASE_URL"] %>\n)
      end
    end

    yaml.sub(section, replacement)
  end
end
