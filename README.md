## Overview

Provides a Rails generator to produce Dockerfiles and related files.  This is being proposed as the generator to be included in Rails 7.1, and a substantial number of pull requests along those lines have already been merged.  This repository contains fixes and features beyond those pull requests.  Highlights:

  * Supports all [Rails supported releases](https://guides.rubyonrails.org/maintenance_policy.html), not just Rails 7.1, and likely works with a number of previous releases.
  * Can be customized using flags on the `generate dockerfile` command, and rerun to produce a custom tailored dockerfile based on detecting the actual features used by your application.
  * Will set `.node_version`, `packageManager` and install gems if needed to deploy your application.
  * Can produce a `docker-compose.yml` file for locally testing your configuration before deploying.

## Usage

```
bundle add dockerfile-rails --optimistic --group development
bin/rails generate dockerfile
```

General options:

* `--force` - overwrite existing files
* `--ci` - include test gems in deployed image
* `--bin-cd` - adjust binstubs to set current working directory
* `--no-prepare` - omit `db:prepare`.  Useful for cloud platforms with [release](https://devcenter.heroku.com/articles/release-phase) phases
* `--platform=s` - specify target platform.  See [FROM](https://docs.docker.com/engine/reference/builder/#from) for details
* `--cache` - use build caching to speed up builds
* `--parallel` - use multi-stage builds to install gems and node modules in parallel
* `--compose` - generate a `docker-compose.yml` file
* `--label=name:value` - specify docker label.  Can be used multiple times.  See [LABEL](https://docs.docker.com/engine/reference/builder/#label) for details

Dependencies:

Generally the dockerfile generator will be able to determine what dependencies you
are actually using.  But should you be using DATABASE_URL, for example, at runtime
additional support may be needed:

* `--mysql` - add mysql libraries
* `--postgresql` - add postgresql libraries
* `--redis` - add redis libraries
* `--sqlite3` - add sqlite3 libraries

Runtime Optimizations:

* `--fullstaq` - use [fullstaq](https://fullstaqruby.org/) [images](https://github.com/evilmartians/fullstaq-ruby-docker) on [quay.io](https://quay.io/repository/evl.ms/fullstaq-ruby?tab=tags&tag=latest)
* `--jemalloc` - use [jemalloc](https://jemalloc.net/) memory allocator
* `--yjit` - enable [YJIT](https://github.com/ruby/ruby/blob/master/doc/yjit/yjit.md) optimizing compiler
* `--swap=n` - allocate swap space.  See [falloc options](https://man7.org/linux/man-pages/man1/fallocate.1.html#OPTIONS) for suffixes

Options are saved between runs into `config/dockerfile.yml`.  To invert a boolean options, add or remove a `no-` prefix from the option name.

## Testing

The current testing strategy is to run `rails new` and `generate dockerfile` with various configurations and compare the generated artifacts with expected results.  `ARG` values in `Dockerfiles` are masked before comparison.

Running all tests, or even a single individual test can be done as follows:

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

Many of the following links relate to the current development status with respect to Rails 7.1 and will be removed once that is resolved.

* [Demos](./DEMO.md) - scripts to copy and paste into an empty directory to launch demo apps
* [Test Results](./test/results) - expected outputs for each test
* [Preparations for Rails 7.1](https://community.fly.io/t/preparations-for-rails-7-1/9512) - [Fly.io](https://fly.io/)'s plans and initial discussions with DHH
* [Rails Dockerfile futures](https://discuss.rubyonrails.org/t/rails-dockerfile-futures/82091/1) - rationale for a generator
* [Fly Cookbooks](https://fly.io/docs/rails/cookbooks/) - deeper dive into Dockerfile design choices
* [app/templates/Dockerfile.tt](https://github.com/rails/rails/blob/main/railties/lib/rails/generators/rails/app/templates/Dockerfile.tt) - current Rails 7.1 template
* Fly.io [Cut over to Rails Dockerfile Generator on Sunday 29 Jan 2023](https://community.fly.io/t/cut-over-to-rails-dockerfile-generator-on-sunday-29-jan-2023/10350)
