# syntax = docker/dockerfile:1

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version and Gemfile
ARG RUBY_VERSION=xxx
FROM ruby:$RUBY_VERSION-slim as base

# Rails app lives here
WORKDIR /rails

# Set production environment
ENV BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    RAILS_ENV="production"

# Update gems and bundler
RUN gem update --system --no-document && \
    gem install -N bundler

# Install packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl gnupg && \
    curl https://oss-binaries.phusionpassenger.com/auto-software-signing-gpg-key.txt | \
      gpg --dearmor > /etc/apt/trusted.gpg.d/phusion.gpg && \
    bash -c 'echo deb https://oss-binaries.phusionpassenger.com/apt/passenger $(source /etc/os-release; echo $VERSION_CODENAME) main > /etc/apt/sources.list.d/passenger.list' && \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y passenger && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives


# Throw-away build stage to reduce size of final image
FROM base as build

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential pkg-config

# Install application gems
COPY --link Gemfile Gemfile.lock .ruby-version ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

# Compile passenger native support
RUN passenger-config build-native-support

# Copy application code
COPY --link . .

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile


# Final stage for app image
FROM base

# Install packages needed for deployment
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libnginx-mod-http-passenger libsqlite3-0 nginx && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# configure nginx and passenger
COPY <<-'EOF' /etc/nginx/sites-enabled/default
server {
    listen 3000;
    root /rails/public;
    passenger_enabled on;
    passenger_ctl hook_detached_process /etc/nginx/hook_detached_process;
    passenger_min_instances 0;
    passenger_pool_idle_time 300;
}
EOF
COPY <<-'EOF' /etc/nginx/sites-enabled/hook_detached_process
#!/usr/bin/env ruby
status = `passenger-status`
processes = status[/^Processes\s*:\s*(\d*)/, 1].to_i
system 'nginx -s stop' if processes == 0
EOF
RUN echo "daemon off;" >> /etc/nginx/nginx.conf && \
    sed -i 's/access_log\s.*;/access_log stdout;/' /etc/nginx/nginx.conf && \
    sed -i 's/error_log\s.*;/error_log stderr info;/' /etc/nginx/nginx.conf && \
    chmod +sx /etc/nginx/sites-enabled/hook_detached_process && \
    sed -i 's/user www-data/user rails/' /etc/nginx/nginx.conf && \
    mkdir /var/run/passenger-instreg

# Copy built artifacts: gems, application
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /rails /rails

# Copy passenger native support
COPY --from=build /root/.passenger/native_support /root/.passenger/native_support

# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    mkdir /data && \
    chown -R 1000:1000 db log storage tmp /data

# Deployment options
ENV DATABASE_URL="sqlite3:///data/production.sqlite3"

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start the server by default, this can be overwritten at runtime
EXPOSE 3000
VOLUME /data
CMD ["nginx"]
