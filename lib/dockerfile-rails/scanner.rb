# frozen_string_literal: true

module DockerfileRails
  module Scanner
    def scan_rails_app
      ### ruby gems ###

      @gemfile = []
      @git = false

      if File.exist? "Gemfile.lock"
        parser = Bundler::LockfileParser.new(Bundler.read_file("Gemfile.lock"))
        @gemfile += parser.specs.map { |spec, version| spec.name }
        @git ||= ENV["RAILS_ENV"] != "test" && parser.specs.any? do |spec|
          spec.source.instance_of? Bundler::Source::Git
        end

        # determine if the application is affected by the net-pop bug
        # https://github.com/ruby/ruby/pull/11006#issuecomment-2176562332
        if RUBY_VERSION == "3.3.3" && @gemfile.include?("net-pop")
          @netpopbug = parser.specs.find { |spec| spec.name == "net-pop" }.dependencies.empty?
        end
      end

      if File.exist? "Gemfile"
        begin
          gemfile_definition = Bundler::Definition.build("Gemfile", nil, [])
          @gemfile += gemfile_definition.dependencies.map(&:name)

          unless ENV["RAILS_ENV"] == "test"
            @git = !gemfile_definition.spec_git_paths.empty?
          end
        rescue => error
          STDERR.puts error.message
        end
      end

      @anycable = @gemfile.include? "anycable-rails"
      @vips = @gemfile.include? "ruby-vips"
      @bootstrap = @gemfile.include? "bootstrap"
      @puppeteer = @gemfile.include? "puppeteer"
      @bootsnap = @gemfile.include? "bootsnap"

      ### database ###

      # start by checkout config/database.yml.  It defaults to sqlite3,
      # but we can't rely on that because DATABASE_URL can override it.
      # if we see anything else, assume the change was intentional.
      database = YAML.load_file("config/database.yml", aliases: true).
        dig("production", "adapter") rescue nil

      if database == "postgresql"
        @postgresql = true
      elsif (database == "mysql") || (database == "mysql2") || (database == "trilogy")
        @mysql = true
      elsif database == "sqlserver"
        @sqlserver = true

      ## if not found (or sqlite3), check the Gemfile
      elsif @gemfile.include? "pg"
        @postgresql = true
      elsif @gemfile.include?("mysql2") || using_trilogy?
        @mysql = true
      elsif @gemfile.include?("activerecord-sqlserver-adapter")
        @sqlserver = true
      elsif @gemfile.include?("sqlite3") || database == "sqlite3"
        # check this one last as sqlite3 may be used in development
        @sqlite3 = true
      end

      ### node modules ###

      @package_json = []

      if File.exist? "package.json"
        @package_json += JSON.load_file("package.json")["dependencies"].keys rescue []
      end

      @puppeteer ||= @package_json.include? "puppeteer"

      ### cable/redis ###

      @cable = ! Dir["app/channels/*.rb"].empty?

      if @cable
        @redis_cable = true
        if (YAML.load_file("config/cable.yml").dig("production", "adapter") rescue "").include? "any_cable"
          @anycable = true
        end
      end

      if (IO.read("config/environments/production.rb") =~ /redis/i rescue false)
        @redis_cache = true
      end

      @redis = @redis_cable || @redis_cache
    end

    def using_trilogy?
      @gemfile.include?("trilogy") || @gemfile.include?("activerecord-trilogy-adapter")
    end

    ### patches ###
    if RUBY_VERSION == "3.3.3"
      Bundler::LockfileParser.new(Bundler.read_file("Gemfile.lock"))

    end
  end
end
