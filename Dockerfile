# Find eligible builder and runner images on Docker Hub. We use Ubuntu/Debian instead of
# Alpine to avoid DNS resolution issues in production.
#
# https://hub.docker.com/r/hexpm/elixir/tags?page=1&name=ubuntu
# https://hub.docker.com/_/ubuntu?tab=tags
#
#
# This file is based on these images:
#
#   - https://hub.docker.com/r/hexpm/elixir/tags - for the build image
#   - https://hub.docker.com/_/debian?tab=tags&page=1&name=bullseye-20210902-slim - for the release image
#   - https://pkgs.org/ - resource for finding needed packages
#   - Ex: hexpm/elixir:1.12.3-erlang-24.2-debian-bullseye-20210902-slim
#
ARG BUILDER_IMAGE="hexpm/elixir:1.15.7-erlang-25.3.2.6-debian-buster-20230612-slim"
ARG RUNNER_IMAGE="python:3.9-slim-bullseye"

FROM ${BUILDER_IMAGE} as builder

# install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git npm \
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

# prepare build dir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force && \
  mix local.rebar --force

# set build ENV
ENV MIX_ENV="prod"

# install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv
COPY resources resources

# note: if your project uses a tool like https://purgecss.com/,
# which customizes asset compilation based on what it finds in
# your Elixir templates, you will need to move the asset compilation
# step down so that `lib` is available.
COPY assets assets

RUN cd assets && npm install

# compile assets
RUN mix assets.deploy

# Compile the release
COPY lib lib

RUN mix compile

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

COPY rel rel
RUN mix release

# start a new build stage so that the final image will only contain
# the compiled release and other runtime necessities
FROM ${RUNNER_IMAGE}

RUN apt-get update -y && apt-get install -y libstdc++6 openssl libncurses5 locales npm imagemagick\
  && apt-get clean && rm -f /var/lib/apt/lists/*_*

RUN pip install csvkit
RUN pip install shapely
RUN pip install svg.path
RUN npm install -g svgo

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR "/app"

RUN chown nobody /app

# Only copy the final release from the build stage
COPY --from=builder --chown=nobody:root /app/_build/prod/rel/barragenspt ./
RUN mkdir "bin/resources"
RUN mkdir "bin/resources/svg"

COPY --from=builder --chown=nobody:root /app/resources/svg/svg_area.py ./bin/resources/svg
COPY --from=builder --chown=nobody:root /app/resources/svg/svgo-config.mjs ./bin/resources/svg
COPY --from=builder --chown=nobody:root /app/resources/svg/pt_map.svg ./bin/resources/svg
COPY --from=builder --chown=nobody:root /app/resources/svg/pt_basins_template.svg ./bin/resources/svg
COPY --from=builder --chown=nobody:root /app/resources/svg/basins_pdsi.svg ./bin/resources/svg

COPY --from=builder --chown=nobody:root /app/resources/dams.csv ./bin/resources
COPY --from=builder --chown=nobody:root /app/resources/albufs.csv ./bin/resources
COPY --from=builder --chown=nobody:root /app/resources/rivers_mapping.csv ./bin/resources

USER nobody

CMD ["/app/bin/server"]

# Appended by flyctl
#ENV ECTO_IPV6 true
#ENV ERL_AFLAGS "-proto_dist inet6_tcp"
