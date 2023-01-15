## Purpose

Provide Rails generators to produce Dockerfiles and related files.

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

Links:

* [Demos](./DEMO.md)
* [Preparations for Rails 7.1](https://community.fly.io/t/preparations-for-rails-7-1/9512)
* [Rails Dockerfile futures](https://discuss.rubyonrails.org/t/rails-dockerfile-futures/82091/1)
* [Fly Cookbooks](https://fly.io/docs/rails/cookbooks/)
