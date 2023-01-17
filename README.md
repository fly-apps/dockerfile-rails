## Overview

Provides Rails generators to produce Dockerfiles and related files.  This is being proposed as the generator to be included in Rails 7.1, and a substantial number of pull requests along those lines have already been merged.  This repository contains fixes and features beyond those pull requests.  Highlights:

  * Supports all [Rails supported releases](https://guides.rubyonrails.org/maintenance_policy.html), not just Rails 7.1, and likely works with a number of previous releases.
  * Can be customized using flags on the `generate dockerfile` command, and rerun to produce a custom tailored dockerfile based on detecting the actual features used by your application.
  * Can produce a `docker-compose.yml` file for locally testing your configuration before deploying.

## Usage

```
bundle add dockerfile-rails --group development
bin/rails generate dockerfile
```

General options:

* `--force` - overwrite existing files
* `--ci` - include test gems in deployed image
* `--cache` - use build caching to speed up builds
* `--parallel` - use multi-stage builds to install gems and node modules in parallel
* `--compose` - generate a `docker-compose.yml` file

Dependencies:

Generally the dockerfile generator will be able to determine what dependencies you
are actually using.  But should you be using DATABASE_URL, for example, at runtime
additional support may be needed:

* `--mysql` - add mysql libraries
* `--posgresql` - add posgresql libraries
* `--redis` - add redis libraries
* `--sqlite3` - add sqlite3 libraries

Optimizations:

* `--fullstaq` - use [fullstaq](https://fullstaqruby.org/) [images](https://github.com/evilmartians/fullstaq-ruby-docker) on [quay.io](https://quay.io/repository/evl.ms/fullstaq-ruby?tab=tags&tag=latest)
* `--jemalloc` - use [jemalloc](https://jemalloc.net/) memory allocator
* `--yjit` - enable [YJIT](https://github.com/ruby/ruby/blob/master/doc/yjit/yjit.md) optimizing compiler.

Links:

* [Demos](./DEMO.md)
* [Preparations for Rails 7.1](https://community.fly.io/t/preparations-for-rails-7-1/9512)
* [Rails Dockerfile futures](https://discuss.rubyonrails.org/t/rails-dockerfile-futures/82091/1)
* [Fly Cookbooks](https://fly.io/docs/rails/cookbooks/)
* [app/templates/Dockerfile.tt](https://github.com/rails/rails/blob/main/railties/lib/rails/generators/rails/app/templates/Dockerfile.tt)
