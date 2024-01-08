# syntax = docker/dockerfile:1

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version and Gemfile
ARG RUBY_VERSION=xxx
FROM ruby:$RUBY_VERSION-alpine as base

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
RUN apk update && \
    apk add tzdata && \
    rm -rf /var/cache/apk/*


# Throw-away build stage to reduce size of final image
FROM base as build

# Install packages needed to build gems and node modules
RUN apk update && \
    apk add build-base curl gyp libpq-dev pkgconfig python3

# Install JavaScript dependencies
ARG NODE_VERSION=xxx
ARG YARN_VERSION=xxx
ENV PATH=/usr/local/node/bin:$PATH
RUN curl -sL https://unofficial-builds.nodejs.org/download/release/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64-musl.tar.gz | tar xz -C /tmp/ && \
    mkdir /usr/local/node && \
    cp -rp /tmp/node-v${NODE_VERSION}-linux-x64-musl/* /usr/local/node/ && \
    npm install -g yarn@$YARN_VERSION && \
    rm -rf /tmp/node-v${NODE_VERSION}-linux-x64-musl

# Install application gems
COPY --link Gemfile Gemfile.lock ./
RUN bundle install && \
    bundle exec bootsnap precompile --gemfile && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

# Install node modules
COPY --link package.json yarn.lock ./
RUN yarn install --frozen-lockfile

# Copy application code
COPY --link . .

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile app/ lib/

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile


# Final stage for app image
FROM base

# Install packages needed for deployment
RUN apk update && \
    apk add curl libpq postgresql-client && \
    rm -rf /var/cache/apk/*

# Copy built artifacts: gems, application
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Run and own only the runtime files as a non-root user for security
RUN addgroup --system --gid 1000 rails && \
    adduser --system rails --uid 1000 --ingroup rails --home /home/rails --shell /bin/sh rails && \
    chown -R 1000:1000 db log storage tmp
USER 1000:1000

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start the server by default, this can be overwritten at runtime
EXPOSE 3000
CMD ["./bin/rails", "server"]
