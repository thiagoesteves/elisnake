# ./Dockerfile
ARG BASE_IMAGE=elixir:1.14.3-alpine
ARG CONTAINER_IMAGE=alpine:3.17.2

FROM ${BASE_IMAGE} AS builder
ENV MIX_ENV=prod
ARG GITHUB_OAUTH_TOKEN
WORKDIR /usr/local/elisnake
# Copies our app source code into the build container
COPY . .

# Clean any copied compilation
RUN rm -rf _build/*

RUN apk update
RUN apk add --no-cache 'build-base=~0.5' git openssh \
 && rm -rf /var/cache/apk/*

# Compile Elixir
RUN mix local.hex --force
RUN mix local.rebar --force

# Git Config, if GITHUB_OAUTH_TOKEN is not set, then deps will be copied over from host
RUN if [ ${GITHUB_OAUTH_TOKEN} != skip_fetch ]; then \
  mkdir /root/.ssh/; \
  ssh-keyscan -t rsa github.com >> ~/.ssh/known_hosts; \
  rm -rf deps/*; \
  git config --global --add user.name ${GITHUB_OAUTH_TOKEN}; \
  git config --global --add url."https://${GITHUB_OAUTH_TOKEN}:x-oauth-basic@github.com/".insteadOf "git@github.com:"; \
  git config --global --add url."https://${GITHUB_OAUTH_TOKEN}:x-oauth-basic@github.com/".insteadOf "ssh://git@github.com/"; \
fi

RUN mix do deps.get, deps.compile, compile
# Build Release
RUN mkdir -p /opt/release \
    && mix release --overwrite \
    && mv _build/${MIX_ENV}/rel/elisnake /opt/release
# Create the runtime container
FROM ${CONTAINER_IMAGE} as candidate

RUN apk upgrade --no-cache && \
    apk add --no-cache bash openssl libgcc libstdc++ ncurses-libs

WORKDIR /usr/local/elisnake
COPY --from=builder /opt/release/elisnake .

# Copy the entrypoint which is not part of the app release into production container.
COPY --from=builder /usr/local/elisnake/entrypoint.sh .
RUN chmod +x ./entrypoint.sh

CMD ["./entrypoint.sh"]
