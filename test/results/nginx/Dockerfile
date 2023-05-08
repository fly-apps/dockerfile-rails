# syntax = docker/dockerfile:1

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version and Gemfile
ARG RUBY_VERSION=xxx
FROM ruby:$RUBY_VERSION-slim as base

# Rails app lives here
WORKDIR /rails

# Set production environment
ENV RAILS_ENV="production" \
    BUNDLE_WITHOUT="development:test" \
    BUNDLE_DEPLOYMENT="1"

# Update gems and bundler
RUN gem update --system --no-document && \
    gem install -N bundler


# Throw-away build stage to reduce size of final image
FROM base as build

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential pkg-config

# Install application gems
COPY --link Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ $BUNDLE_PATH/ruby/*/cache $BUNDLE_PATH/ruby/*/bundler/gems/*/.git

# Copy application code
COPY --link . .

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE=DUMMY ./bin/rails assets:precompile


# Final stage for app image
FROM base

# Install packages needed for deployment
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y libsqlite3-0 nginx && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# configure nginx
RUN gem install foreman && \
    sed -i 's|pid /run|pid /rails/tmp/pids|' /etc/nginx/nginx.conf && \
    sed -i 's/access_log\s.*;/access_log \/dev\/stdout;/' /etc/nginx/nginx.conf && \
    sed -i 's/error_log\s.*;/error_log \/dev\/stderr info;/' /etc/nginx/nginx.conf

COPY <<-"EOF" /etc/nginx/sites-available/default
server {
  listen 3000 default_server;
  listen [::]:3000 default_server;
  access_log /dev/stdout;

  root /rails/public;

  location /cable {
    proxy_pass http://localhost:8082/cable;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "Upgrade";
    proxy_set_header Host $host;
  }

  location / {
    try_files $uri @backend;
  }

  location @backend {
    proxy_pass http://localhost:3001;
    proxy_set_header origin 'http://localhost:3000';
  }
}
EOF

# Copy built artifacts: gems, application
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /rails /rails

# Run and own only the runtime files as a non-root user for security
RUN useradd rails --create-home --shell /bin/bash && \
    chown rails:rails /var/lib/nginx /var/log/nginx/* && \
    chown -R rails:rails db log tmp
USER rails:rails

# Deployment options
ENV PORT="3001" \
    RAILS_LOG_TO_STDOUT="1"

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Build a Procfile for production use
COPY <<-"EOF" /rails/Procfile.prod
nginx: /usr/sbin/nginx -g "daemon off;"
rails: ./bin/rails server -p 3001
EOF

# Start the server by default, this can be overwritten at runtime
EXPOSE 3000
CMD ["foreman", "start", "--procfile=Procfile.prod"]
