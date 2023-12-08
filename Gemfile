# frozen_string_literal: true

source "https://rubygems.org"
gemspec

group :test do
  gem "minitest"
  gem "bootsnap"
end

group :rubocop do
  gem "rubocop", ">= 1.25.1", require: false
  gem "rubocop-minitest", require: false
  gem "rubocop-packaging", require: false
  gem "rubocop-performance", require: false
  gem "rubocop-rails", require: false
end

group :development do
  gem "rmagick"
  gem "pg"
  gem "mysql2"
end

gem "quality_extensions", "~> 1.4"
