# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name        = "dockerfile-rails"
  spec.version     = "1.7.2"
  spec.authors     = [
    "Sam Ruby",
  ]
  spec.email       = "rubys@intertwingly.net"
  spec.homepage    = "https://github.com/fly-apps/dockerfile-rails"
  spec.summary     = "Dockerfile generator for Rails"
  spec.license     = "MIT"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
  }

  spec.files = Dir["lib/**/*", "MIT-LICENSE", "Rakefile", "*.md"]

  spec.add_dependency "rails", ">= 3.0.0"

  spec.required_ruby_version = ">= 2.6.0"
end
