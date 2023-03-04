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

```
bundle add dockerfile-rails --optimistic --group development
bin/rails generate dockerfile
```

### General option:

* `--force` - overwrite existing files

### Runtime Optimizations:

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
* `--nginx` - serve static files via [nginx](https://www.nginx.com/).  May require `--root` on some targets to access `/dev/stdout`
* `--no-link` - don't add [--link](https://docs.docker.com/engine/reference/builder/#copy---link) to COPY statements.  Some tools (like at the moment, [buildah](https://www.redhat.com/en/topics/containers/what-is-buildah)) don't yet support this feature.
* `--no-lock` - don't add linux platforms, set `BUNDLE_DEPLOY`, or `--frozen-lockfile`.  May be needed at times to work around a [rubygems bug](https://github.com/rubygems/rubygems/issues/6082#issuecomment-1329756343).
* `--sudo` - install and configure sudo to enable `sudo -iu rails` access to full environment

### Add a Database:

Generally the dockerfile generator will be able to determine what dependencies you
are actually using.  But should you be using DATABASE_URL, for example, at runtime
additional support may be needed:

* `--mysql` - add mysql libraries
* `--postgresql` - add postgresql libraries
* `--redis` - add redis libraries
* `--sqlite3` - add sqlite3 libraries

### Add a package/environment variable/build argument:

Not all of your needs can be determined by scanning your application.  For example, I like to add [vim](https://www.vim.org/) and [procps](https://packages.debian.org/bullseye/procps).

 * `--add package...` - add one or more debian packages
 * `--arg=name:value` - add a [build argument](https://docs.docker.com/engine/reference/builder/#arg)
 * `--env=name:value` - add an environment variable
 * `--remove package...` - remove package from "to be added" list

 Each of these can be tailored to a specific build phase by adding `-base`, `-build`, or `-deploy` after the flag name (e.g `--env-build:`).  If no such suffix is found, the default for arg is `-base`, and the default for the rest is `-deploy`.  Removal of an arg or environment variable is done by leaving the value blank.

### Configuration:

* `--bin-cd` - adjust binstubs to set current working directory
* `--label=name:value` - specify docker label.  Can be used multiple times.  See [LABEL](https://docs.docker.com/engine/reference/builder/#label) for detail
* `--no-prepare` - omit `db:prepare`.  Useful for cloud platforms with [release](https://devcenter.heroku.com/articles/release-phase) phases
* `--platform=s` - specify target platform.  See [FROM](https://docs.docker.com/engine/reference/builder/#from) for details
* `--precompile=defer` - may be needed when your configuration requires access to secrets that are not available at build time.  Results in larger images and slower deployments.
* `--root` - run application as root

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
ruby test/test_minimal.rb
```

To assis with this process, outputs of tests can be captured automatically.  This is useful when adding new tests and when making a change that affects many tests.  Be sure to inspect the output (e.g., by using `git diff`) before committing.

```
rake test:capture
```

If you are running a single test, the following environment variables settings may be helpful:

 * `RAILS_ENV=TEST` will match the environment used to produce the captured outputs.
 * `TEST_CAPTURE=1` will capture test results.
 * `TEST_KEEP=1` will leave the test app behind for inspection after the test completes.

## Links

The following links relate to the current development status with respect to Rails 7.1 and will be removed once that is resolved.

* [Preparations for Rails 7.1](https://community.fly.io/t/preparations-for-rails-7-1/9512) - [Fly.io](https://fly.io/)'s plans and initial discussions with DHH
* [Rails Dockerfile futures](https://discuss.rubyonrails.org/t/rails-dockerfile-futures/82091/1) - rationale for a generator
* [Fly Cookbooks](https://fly.io/docs/rails/cookbooks/) - deeper dive into Dockerfile design choices
* [app/templates/Dockerfile.tt](https://github.com/rails/rails/blob/main/railties/lib/rails/generators/rails/app/templates/Dockerfile.tt) - current Rails 7.1 template
* Fly.io [Cut over to Rails Dockerfile Generator on Sunday 29 Jan 2023](https://community.fly.io/t/cut-over-to-rails-dockerfile-generator-on-sunday-29-jan-2023/10350)
* Fly.io [FAQ](https://fly.io/docs/rails/getting-started/dockerfiles/)
* DDH's [target](https://github.com/rails/rails/pull/47372#issuecomment-1438971730)
