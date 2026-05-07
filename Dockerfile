# syntax = docker/dockerfile:1

ARG RUBY_VERSION=3.3.1
FROM docker.io/library/ruby:$RUBY_VERSION-alpine AS base

WORKDIR /rails

RUN apk add --no-cache \
    curl \
    sqlite \
    sqlite-libs \
    jemalloc

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development" \
    LD_PRELOAD="/usr/lib/libjemalloc.so.2"

FROM base AS build

RUN apk add --no-cache \
    build-base \
    git \
    yaml-dev \
    pkgconf \
    sqlite-dev

COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

COPY . .

RUN bundle exec bootsnap precompile app/ lib/

RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

FROM base

COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

RUN addgroup -S -g 1000 rails && \
    adduser -S -u 1000 -G rails -h /home/rails -s /bin/sh rails && \
    chown -R rails:rails db log storage tmp
USER 1000:1000

ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 3000
CMD ["./bin/rails", "server"]
