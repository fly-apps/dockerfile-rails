## Purpose

Provide Rails generators to produce Dockerfiles and related files.

## Usage

```
bundle add dockerfile-rails
bin/rails generate dockerfile
```

General options:

* `--force` - overwrite existing files
* `--ci` - include test gems in bundle
* `--cache` - use build caching to speed up builds
* `--parallel` - use multi-stage builds to install gems and node modules in parallel

Dependencies:

Generally the dockerfile generator will be able to determine what dependencies you
are actually using.  But should you be using DATABASE_URL, for example, at runtime
additional support may be needed:

* `--mysql` - add mysql libraries
* `--posgresql` - add posgresql libraries
* `--redis` - add redis libraries
* `--sqlite3` - add sqlite3 libraries