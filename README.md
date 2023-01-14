## Purpose

Provide Rails generators to produce Dockerfiles and related files.

## Usage

```
bundle add dockerfile-rails
bin/rails generate dockerfile
```

General options:
  `--force` - overwrite existing files
  `--ci` - include test gems in bundle