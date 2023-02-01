Gem::Specification.new do |spec|
  spec.name        = "dockerfile-rails"
  spec.version     = '1.0.4'
  spec.authors     = [ 
    "Sam Ruby",
  ]
  spec.email       = "rubys@intertwingly.net"
  spec.homepage    = "https://github.com/rubys/dockerfile-rails"
  spec.summary     = "Dockerfile generator for Rails"
  spec.license     = "MIT"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
  }

  spec.files = Dir["lib/**/*", "MIT-LICENSE", "Rakefile", "*.md"]

  spec.add_dependency "rails"
end
