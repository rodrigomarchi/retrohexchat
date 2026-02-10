# ---- Build Stage ----
ARG ELIXIR_VERSION=1.17.3
ARG OTP_VERSION=27.2
ARG DEBIAN_VERSION=bookworm-20241202

ARG BUILDER_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNNER_IMAGE="debian:${DEBIAN_VERSION}-slim"

FROM ${BUILDER_IMAGE} AS builder

RUN apt-get update -y && \
    apt-get install -y build-essential git npm && \
    apt-get clean && rm -f /var/lib/apt/lists/*_*

ENV MIX_ENV=prod

WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && mix local.rebar --force

# Copy dependency manifests first for cache efficiency
COPY mix.exs mix.lock ./
COPY config/config.exs config/prod.exs config/runtime.exs config/
COPY apps/retro_hex_chat/mix.exs apps/retro_hex_chat/
COPY apps/retro_hex_chat_web/mix.exs apps/retro_hex_chat_web/

RUN mix deps.get

RUN mix deps.compile

# Install npm dependencies (98.css)
COPY apps/retro_hex_chat_web/assets/package.json apps/retro_hex_chat_web/assets/package-lock.json apps/retro_hex_chat_web/assets/
RUN npm ci --prefix apps/retro_hex_chat_web/assets

# Copy all application source
COPY apps apps

# Build assets
RUN mix assets.deploy

# Compile the project
RUN mix compile

# Build the release
RUN mix release

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

CMD ["bin/retro_hex_chat_umbrella", "start"]
