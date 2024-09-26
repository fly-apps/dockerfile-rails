## Overview

Provides a Rails generator to produce Dockerfiles and related files.  This is being proposed as the generator to be included in Rails 7.1, and a substantial number of pull requests along those lines have already been merged.  This repository contains fixes and features beyond those pull requests.  Highlights:

  * Supports all [Rails supported releases](https://guides.rubyonrails.org/maintenance_policy.html), not just Rails 7.1, and likely works with a number of previous releases.
  * Can be customized using flags on the `generate dockerfile` command, and rerun to produce a custom tailored dockerfile based on detecting the actual features used by your application.
  * Will set `.node_version`, `packageManager` and install gems if needed to deploy your application.
  * Can produce a `docker-compose.yml` file for locally testing your configuration before deploying.

For more background:

* [Motivation](./MOTIVATION.md) - why this generator was created and what problems it is meant to solve
* [Demos](./DEMO.md) - scripts to copy and paste into an empty directory to launch demo apps
* [Test Results](./test/results) - expected outputs for each test

## Usage

Install from the root of your Rails project by running the following.

```
bundle add dockerfile-rails --optimistic --group development
bin/rails generate dockerfile
```

The `--optimistic` flag will make sure you always get the latest `dockerfile-rails` gem when you run `bundle update && rails g dockerfile`.

### General option:

* `--force` - overwrite existing files
* `--skip` - keep existing files

If neither are specified, you will be prompted if a file exists with
different contents.  If both are specified, `--force` takes precedence.

### Runtime Optimizations:

* `--alpine` - use [alpine](https://www.alpinelinux.org/) as base image (requires [Alpine <= 3.18 OR Rails >= 8.0](https://github.com/sparklemotion/sqlite3-ruby/issues/434))
* `--fullstaq` - use [fullstaq](https://fullstaqruby.org/) [images](https://github.com/evilmartians/fullstaq-ruby-docker) on [quay.io](https://quay.io/repository/evl.ms/fullstaq-ruby?tab=tags&tag=latest)
* `--jemalloc` - use [jemalloc](https://jemalloc.net/) memory allocator
* `--swap=n` - allocate swap space.  See [falloc options](https://man7.org/linux/man-pages/man1/fallocate.1.html#OPTIONS) for suffixes
* `--yjit` - enable [YJIT](https://github.com/ruby/ruby/blob/master/doc/yjit/yjit.md) optimizing compiler

### Build optimizations:

* `--cache` - use build caching to speed up builds
* `--parallel` - use multi-stage builds to install gems and node modules in parallel

### Add/remove a Feature:

* `--ci` - include test gems in deployed image
* `--compose` - generate a `docker-compose.yml` file
* `--max-idle=n` - exit afer *n* seconds of inactivity.  Supports [iso 8601](https://en.wikipedia.org/wiki/ISO_8601#Durations) and [sleep](https://man7.org/linux/man-pages/man1/sleep.1.html#DESCRIPTION) syntaxes.  Uses passenger for now, awaiting [puma](https://github.com/puma/puma/issues/2580) support.
* `--nginx` - serve static files via [nginx](https://www.nginx.com/).  May require `--root` on some targets to access `/dev/stdout`
* `--thruster` - serve static files via [thruster](https://github.com/basecamp/thruster?tab=readme-ov-file#thruster).
* `--link` - add [--link](https://docs.docker.com/engine/reference/builder/#copy---link) to COPY statements.  Some tools (like at the moment, [buildah](https://www.redhat.com/en/topics/containers/what-is-buildah)) don't yet support this feature.
* `--no-lock` - don't add linux platforms, set `BUNDLE_DEPLOY`, or `--frozen-lockfile`.  May be needed at times to work around a [rubygems bug](https://github.com/rubygems/rubygems/issues/6082#issuecomment-1329756343).
* `--sudo` - install and configure sudo to enable `sudo -iu rails` access to full environment

#### Error Tracking & Alerting:
* `--rollbar` - install gem and a default initializer for [Rollbar](https://rollbar.com/#)
* `--sentry` - install gems and a default initializer for [Sentry](https://sentry.io/welcome/)

### Add a Database:

Generally the dockerfile generator will be able to determine what dependencies you
are actually using.  But should you be using DATABASE_URL, for example, at runtime
additional support may be needed:

* `--litefs` - use [LiteFS](https://fly.io/docs/litefs/)
* `--mysql` - add mysql libraries
* `--postgresql` - add postgresql libraries
* `--redis` - add redis libraries
* `--sqlite3` - add sqlite3 libraries
* `--sqlserver` - add SQL Server libraries

### Add a package/environment variable/build argument:

Not all of your needs can be determined by scanning your application.  For example, I like to add [vim](https://www.vim.org/) and [procps](https://packages.debian.org/bullseye/procps).

 * `--add package...` - add one or more debian packages
 * `--arg=name:value` - add a [build argument](https://docs.docker.com/engine/reference/builder/#arg)
 * `--env=name:value` - add an environment variable
 * `--remove package...` - remove package from "to be added" list

Args and environment variables can be tailored to a specific build phase by adding `-base`, `-build`, or `-deploy` after the flag name (e.g `--add-build freetds-dev --add-deploy freetds-bin`).  If no such suffix is found, the default for arg is `-base`, and the default for env is `-deploy`.  Removal of an arg or environment variable is done by leaving the value blank (e.g `--env-build=PORT:`).

### Configuration:

* `--bin-cd` - adjust binstubs to set current working directory
[autocrlf](https://git-scm.com/book/en/v2/Customizing-Git-Git-Configuration#_core_autocrlf) enabled or may not be able to set bin stubs as executable.
* `--label=name:value` - specify docker label.  Can be used multiple times.  See [LABEL](https://docs.docker.com/engine/reference/builder/#label) for detail
* `--no-prepare` - omit `db:prepare`.  Useful for cloud platforms with [release](https://devcenter.heroku.com/articles/release-phase) phases
* `--passenger` - use [Phusion Passenger](https://www.phusionpassenger.com/) under [nginx](https://www.nginx.com/)
* `--platform=s` - specify target platform.  See [FROM](https://docs.docker.com/engine/reference/builder/#from) for details
* `--variant=s` - dockerhub ruby variant, defaults to `slim`.  See [docker official images](https://hub.docker.com/_/ruby) for list.
* `--precompile=defer` - may be needed when your configuration requires access to secrets that are not available at build time.  Results in larger images and slower deployments.
* `--root` - run application as root
* `--windows` - make Dockerfile work for Windows users that may have set `git config --global core.autocrlf true`
* `--private-gemserver-domain=gems.example.com` - set the domain name of your private gemserver.  This is used to tell bundler for what domain to use the credentials of a private gemserver provided via a docker secret
* `--no-precompiled-gems` - compile all gems instead of using precompiled versions

### Advanced Customization:

There may be times where feature detection plus flags just aren't enough.  As an example, you may wish to configure and run multiple processes.

* `--instructions=path` - a dockerfile fragment to be inserted into the final document.
* `--migrate=cmd` - a replacement (generally a script) for `db:prepare`/`db:migrate`.
* `--no-gemfile-updates` - do not modify my gemfile.
* `--procfile=path` - a [Procfile](https://github.com/ddollar/foreman#foreman) to use in place of launching Rails directly.
* `--registry=another.docker.registry.com` - use a different registry for sourcing Docker images (e.g. public.ecr.aws).

Like with environment variables, packages, and build args, `--instructions` can be tailored to a specific build phase by adding `-base`, `-build`, or `-deploy` after the flag name, with the default being `-deploy`.

Additionally, if the instructions start with a [shebang](https://en.wikipedia.org/wiki/Shebang_(Unix)) instead the file being treated as a Dockerfile fragment, the file is treated as a script and a `RUN` statement is added to your Dockerfile instead.

---

Options are saved between runs into `config/dockerfile.yml`.  To invert a boolean options, add or remove a `no-` prefix from the option name.

## Testing

A single invocation of `rake test:all` will run all of the tests defined.  dockerfile-rails has are three types of tests:

  * `rake test:rubocop` runs [rubocop](https://github.com/rubocop/rubocop) using the same options as the Rails codebase.
  * `rake test:system` creates a new esbuild application, generates a dockerfile, builds and runs it.  As this is time consuming, only one application is tested this way at this time, and a `--javascript` example was selected as it exercises a large portion of the features.
  * `rake test` runs integration tests, as described below

The current integration testing strategy is to run `rails new` and `generate dockerfile` with various configurations and compare the generated artifacts with expected results.  `ARG` values in `Dockerfiles` are masked before comparison.

Running all integration tests, or even a single individual test can be done as follows:

```
rake test

bundle exec rake test TEST=test/test_minimal.rb
bundle exec ruby test/test_minimal.rb
```

To assist with this process, outputs of tests can be captured automatically.  This is useful when adding new tests and when making a change that affects many tests.  Be sure to inspect the output (e.g., by using `git diff`) before committing.

```
rake test:capture
```

If you are running a single test, the following environment variables settings may be helpful:

 * `RAILS_ENV=TEST` will match the environment used to produce the captured outputs.
 * `TEST_CAPTURE=1` will capture test results.
 * `TEST_KEEP=1` will leave the test app behind for inspection after the test completes.

## Historical Links

The following links relate to the coordination between this package and Rails 7.1.

* [Preparations for Rails 7.1](https://community.fly.io/t/preparations-for-rails-7-1/9512) - [Fly.io](https://fly.io/)'s plans and initial discussions with DHH
* [Rails Dockerfile futures](https://discuss.rubyonrails.org/t/rails-dockerfile-futures/82091/1) - rationale for a generator
* [Fly Cookbooks](https://fly.io/docs/rails/cookbooks/) - deeper dive into Dockerfile design choices
* [app/templates/Dockerfile.tt](https://github.com/rails/rails/blob/main/railties/lib/rails/generators/rails/app/templates/Dockerfile.tt) - current Rails 7.1 template
* Fly.io [Cut over to Rails Dockerfile Generator on Sunday 29 Jan 2023](https://community.fly.io/t/cut-over-to-rails-dockerfile-generator-on-sunday-29-jan-2023/10350)
* Fly.io [FAQ](https://fly.io/docs/rails/getting-started/dockerfiles/)
* DDH's [target](https://github.com/rails/rails/pull/47372#issuecomment-1438971730)

Parallel efforts for Hanami:

* [Proposal](https://discourse.hanamirb.org/t/dockerfile-hanami/816)
