# frozen_string_literal: true

require "erb"
require_relative "../dockerfile-rails/scanner.rb"

class DockerfileGenerator < Rails::Generators::Base
  include DockerfileRails::Scanner

  BASE_DEFAULTS = {
    "bin-cd" => false,
    "cache" => false,
    "ci" => false,
    "compose" => false,
    "fullstaq" => false,
    "jemalloc" => false,
    "label" => {},
    "link" => true,
    "lock" => true,
    "max-idle" => nil,
    "mysql" => false,
    "nginx" => false,
    "parallel" => false,
    "passenger" => false,
    "platform" => nil,
    "postgresql" => false,
    "precompile" => nil,
    "prepare" => true,
    "redis" => false,
    "root" => false,
    "sqlite3" => false,
    "sudo" => false,
    "swap" => nil,
    "yjit" => false,
  }.then { |hash| Struct.new(*hash.keys.map(&:to_sym)).new(*hash.values) }

  OPTION_DEFAULTS = BASE_DEFAULTS.dup

  @@labels = {}
  @@packages = { "base" => [], "build" => [], "deploy" => [] }
  @@vars = { "base" => {}, "build" => {}, "deploy" => {} }
  @@args = { "base" => {}, "build" => {}, "deploy" => {} }

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

      @@labels = options[:label].stringify_keys if options.include? :label
    end
  end

  class_option :ci, type: :boolean, default: OPTION_DEFAULTS.ci,
    desc: "include test gems in bundle"

  class_option :link, type: :boolean, default: OPTION_DEFAULTS.lock,
    desc: "use COPY --link whenever possible"

  class_option :lock, type: :boolean, default: OPTION_DEFAULTS.lock,
    desc: "lock Gemfile/package.json"

  class_option :precompile, type: :string, default: OPTION_DEFAULTS.precompile,
    desc: 'if set to "defer", assets:precompile will be done at deploy time'

  class_option "bin-cd", type: :boolean, default: OPTION_DEFAULTS["bin-cd"],
    desc: "modify binstubs to set working directory"

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

  class_option :postgresql, aliases: "--postgres", type: :boolean, default: OPTION_DEFAULTS.postgresql,
    desc: "include postgresql libraries"

  class_option :mysql, type: :boolean, default: OPTION_DEFAULTS.mysql,
    desc: "include mysql libraries"

  class_option :platform, type: :string, default: OPTION_DEFAULTS.platform,
    desc: "image platform (example: linux/arm64)"

  class_option :jemalloc, type: :boolean, default: OPTION_DEFAULTS.jemalloc,
    desc: "use jemalloc alternative malloc implementation"

  class_option :fullstaq, type: :boolean, default: OPTION_DEFAULTS.fullstaq,
    descr: "use Fullstaq Ruby image from Quay.io"

  class_option :yjit, type: :boolean, default: OPTION_DEFAULTS.yjit,
    desc: "enable YJIT optimizing compiler"

  class_option :label, type: :hash, default: {},
    desc: "Add Docker label(s)"

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
      @@args.delete phase if @@args[phase].empty?
    end

    @dockerfile_config["packages"] = @@packages
    @dockerfile_config["envs"] = @@vars
    @dockerfile_config["args"] = @@args

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
    %w(packages envs args).each do |key|
      @dockerfile_config.delete key if @dockerfile_config[key].empty?
    end

    if !@dockerfile_config.empty?
      template "dockerfile.yml.erb", "config/dockerfile.yml", force: true
    elsif File.exist? "config/dockerfile.yml"
      remove_file "config/dockerfile.yml"
    end
  end

private
  def render(options)
    scope = (Class.new do
      def initialize(obj, locals)
        @_obj = obj
        @_locals = locals.then do |hash|
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

  def run_as_root?
    options.root?
  end

  def using_node?
    return @using_node if @using_node != nil
    @using_node = File.exist? "package.json"
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

  def using_sidekiq?
    @gemfile.include?("sidekiq")
  end

  def parallel?
    using_node? && options.parallel
  end

  def keeps?
    return @keeps if @keeps != nil
    @keeps = !!Dir["**/.keep"]
  end

  def install_gems
    ENV["BUNDLE_IGNORE_MESSAGES"] = "1"

    gemfile = IO.read("Gemfile")

    unless /^\s*source\s/.match?(gemfile)
      gemfile = %{source "https://rubygems.org"\n} + gemfile
    end

    if options.postgresql? || @postgresql
      system "bundle add pg --skip-install" unless @gemfile.include? "pg"
    end

    if options.mysql? || @mysql
      system "bundle add mysql2 --skip-install" unless @gemfile.include? "mysql2"
    end

    if options.redis? || using_redis?
      system "bundle add redis --skip-install" unless @gemfile.include? "redis"
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
      gems += %w(irb reline) - @gemfile unless Gem.ruby_version >= "3.2.2"
    end

    gems.sort
  end

  def base_packages
    packages = []
    packages += @@packages["base"] if @@packages["base"]

    if using_execjs?
      packages += %w(curl)
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

    packages.sort.uniq
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

    # add databases: sqlite3, postgres, mysql
    packages << "pkg-config" if options.sqlite3? || @sqlite3
    packages << "libpq-dev" if options.postgresql? || @postgresql
    packages << "default-libmysqlclient-dev" if options.mysql? || @mysql

    # add git if needed to install gems
    packages << "git" if @git

    # ActiveStorage preview support
    packages << "libvips" if @gemfile.include? "ruby-vips"

    # Rmagick gem
    packages += %w[pkg-config libmagickwand-dev] if @gemfile.include? "rmagick"

    # node support, including support for building native modules
    if using_node?
      packages += %w(node-gyp pkg-config)
      packages += %w(curl) unless using_execjs? || using_puppeteer?

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

    packages.sort.uniq
  end

  def deploy_packages
    packages = []
    packages += @@packages["deploy"] if @@packages["deploy"]

    # start with databases: sqlite3, postgres, mysql
    packages << "libsqlite3-0" if options.sqlite3? || @sqlite3
    packages << "postgresql-client" if options.postgresql? || @postgresql
    packages << "default-mysql-client" if options.mysql || @mysql

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
    packages += %w(passenger libnginx-mod-http-passenger) if using_passenger?

    # nginx
    packages << "nginx" if options.nginx? || using_passenger?

    # sudo
    packages << "sudo" if options.sudo?

    packages.sort
  end

  def deploy_repos
    repos = []
    packages = []

    if using_puppeteer? && deploy_packages.include?("google-chrome-stable")
      packages += %w(gnupg curl)
      repos += [
       "curl https://oss-binaries.phusionpassenger.com/auto-software-signing-gpg-key.txt |",
       "  gpg --dearmor > /etc/apt/trusted.gpg.d/google-archive.gpg &&",
       'echo "deb http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list'
      ]
    end

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
        repos.unshift "apt-get update -qq &&",
          "apt-get install --no-install-recommends -y #{packages.join(" ")} &&"
      end

      repos.join(" \\\n    ") + " && \\\n    "
    end
  end

  def base_env
    env = {
      "RAILS_ENV" => "production",
      "BUNDLE_WITHOUT" => options.ci? ? "development" : "development:test"
    }

    if options.lock?
      env["BUNDLE_DEPLOYMENT"] = "1"
    end

    if @@args["base"]
      env.merge! @@args["base"].to_h { |key, value| [key, "$#{key}"] }
    end

    env.merge! @@vars["base"] if @@vars["base"]

    env.map { |key, value| "#{key}=#{value.inspect}" }
  end

  def build_env
    env = {}

    if using_execjs?
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

    env["PORT"] = "3001" if options.nginx? && !using_passenger?

    if Rails::VERSION::MAJOR < 7 || Rails::VERSION::STRING.start_with?("7.0")
      env["RAILS_LOG_TO_STDOUT"] = "1"
      env["RAILS_SERVE_STATIC_FILES"] = "true" unless options.nginx?
    end

    if options.yjit?
      env["RUBY_YJIT_ENABLE"] = "1"
    end

    if options.jemalloc? && !options.fullstaq?
      if (options.platform || Gem::Platform.local.cpu).include? "arm"
        env["LD_PRELOAD"] = "/usr/lib/aarch64-linux-gnu/libjemalloc.so.2"
      else
        env["LD_PRELOAD"] = "/usr/lib/x86_64-linux-gnu/libjemalloc.so.2"
      end

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

    env.merge! @@vars["base"] if @@vars["base"]

    env.map { |key, value| "#{key}=#{value.inspect}" }
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
    if options["bin-cd"]
      binfixups.push %{grep -l '#!/usr/bin/env ruby' /rails/bin/* | xargs sed -i '/^#!/aDir.chdir File.expand_path("..", __dir__)'}
    end

    binfixups
  end

  def deploy_database
    if options.postgresql? || @postgresql
      "postgresql"
    elsif options.mysql || @mysql
      "mysql"
    else
      "sqlite3"
    end
  end

  def node_version
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
    "latest"
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

    Dir["#{client}/{package.json,package-lock.json,yarn.lock}"]
  end

  def dbprep_command
    if Rails::VERSION::MAJOR >= 6
      "db:prepare"
    else
      "db:migrate"
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
    else
      {
        rails: "./bin/rails server"
      }
    end
  end

  def more_docker_ignores
    more = ""

    if @gemfile.include?("vite_ruby")
      lines = IO.read(".gitignore")[/^# Vite.*?\n\n/m].to_s.chomp.lines -
         ["node_modules\n"]

      more += "\n" + lines.join
    end

    more
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
end
