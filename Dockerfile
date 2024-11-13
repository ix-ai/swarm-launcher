# Multi-arch swarm-launcher image, using docker-compose
FROM alpine:3.20.3@sha256:1e42bbe2508154c9126d48c2b8a75420c3544343bf86fd041fb7527e017a4b4a

LABEL maintainer="docker@ix.ai" \
      ai.ix.repository="ix.ai/swarm-launcher" \
      org.opencontianers.image.description="A docker image to allow the launch of container in docker swarm, with options normally unavailable to swarm mode" \
      org.opencontainers.image.source="https://gitlab.com/ix.ai/swarm-launcher"

# renovate: datasource=repology depName=alpine_3_20/bash versioning=loose
ARG BASH_VERSION="5.2.26-r0"
# renovate: datasource=repology depName=alpine_3_20/curl versioning=loose
ARG CURL_VERSION="8.9.1-r2"
# renovate: datasource=repology depName=alpine_3_20/jq versioning=loose
ARG JQ_VERSION="1.7.1-r0"
# renovate: datasource=repology depName=alpine_3_20/docker-cli-compose versioning=loose
ARG DOCKER_CLI_COMPOSE_VERSION="2.27.0-r3"

RUN apk add --no-cache \
    bash="${BASH_VERSION}" \
    curl="${CURL_VERSION}" \
    jq="${JQ_VERSION}" \
    docker-cli-compose="${DOCKER_CLI_COMPOSE_VERSION}"

# add entrypoint.sh launcher script
COPY entrypoint.sh /

# run the image
ENTRYPOINT ["/entrypoint.sh"]
