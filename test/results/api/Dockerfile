# syntax=docker/dockerfile:1
# check=error=true

# This Dockerfile is designed for production, not development. Use with Kamal or build'n'run by hand:
# docker build -t demo .
# docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value from config/master.key> --name demo demo

# For a containerized dev environment, see Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=xxx
ARG NODE_VERSION=xxx

FROM node:$NODE_VERSION-slim AS client

WORKDIR /rails/my-app

ENV NODE_ENV=production

# Install node modules
COPY my-app/package.json ./
RUN npm install

# build client application
COPY my-app .
RUN npm run build


FROM ruby:$RUBY_VERSION-slim AS base

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


# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential pkg-config

# Install application gems
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    bundle exec bootsnap precompile --gemfile && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile app/ lib/


# Final stage for app image
FROM base

# Install packages needed for deployment
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libsqlite3-0 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Copy built artifacts: gems, application
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Copy built client
COPY --from=client /rails/my-app/build /rails/public

# Run and own only the runtime files as a non-root user for security
ARG UID=xxx \
    GID=1000
RUN groupadd -f -g $GID rails && \
    useradd -u $UID -g $GID rails --create-home --shell /bin/bash && \
    mkdir /data && \
    chown -R rails:rails db log storage tmp /data
USER rails:rails

# Deployment options
ENV DATABASE_URL="sqlite3:///data/production.sqlite3"

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start server via Thruster by default, this can be overwritten at runtime
EXPOSE 80
VOLUME /data
CMD ["./bin/thrust", "./bin/rails", "server"]
