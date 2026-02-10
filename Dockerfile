# syntax=docker/dockerfile:1

# ---- Build Stage ----
ARG ELIXIR_VERSION=1.17.3
ARG OTP_VERSION=27.2
ARG DEBIAN_VERSION=bookworm-20241202

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}-slim"

FROM ${BUILDER_IMAGE} AS builder

RUN apt-get update -y && \
    apt-get install -y build-essential && \
    apt-get clean && rm -f /var/lib/apt/lists/*_*

ENV MIX_ENV=prod

WORKDIR /app

# Install hex + rebar (baked into image layer)
RUN mix local.hex --force && mix local.rebar --force

# Copy dependency manifests first for cache efficiency
COPY mix.exs mix.lock ./
COPY config/config.exs config/prod.exs config/runtime.exs config/
COPY apps/retro_hex_chat/mix.exs apps/retro_hex_chat/
COPY apps/retro_hex_chat_web/mix.exs apps/retro_hex_chat_web/

# Fetch and compile dependencies (hex download cache persists across rebuilds)
RUN --mount=type=cache,target=/root/.hex \
    mix deps.get && mix deps.compile

# Copy all application source (98.css is vendored, no npm needed)
COPY apps apps
COPY rel rel

# Build assets, compile, and create release
RUN mix assets.deploy && \
    mix compile && \
    mix release

# ---- Runtime Stage ----
FROM ${RUNNER_IMAGE}

RUN apt-get update -y && \
    apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates && \
    apt-get clean && rm -f /var/lib/apt/lists/*_* && \
    sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR /app

RUN useradd --create-home app
USER app

COPY --from=builder --chown=app:app /app/_build/prod/rel/retro_hex_chat_umbrella ./

CMD ["bin/server"]
