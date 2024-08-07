# Multi-arch swarm-launcher image, using docker-compose
FROM alpine:3.20.2@sha256:0a4eaa0eecf5f8c050e5bba433f58c052be7587ee8af3e8b3910ef9ab5fbe9f5

LABEL maintainer="docker@ix.ai" \
      ai.ix.repository="ix.ai/swarm-launcher" \
      org.opencontianers.image.description="A docker image to allow the launch of container in docker swarm, with options normally unavailable to swarm mode" \
      org.opencontainers.image.source="https://ix.ai/swarm-launcher"

# renovate: datasource=repology depName=alpine_3_20/bash
ARG BASH_VERSION="5.2.26-r0"
# renovate: datasource=repology depName=alpine_3_20/curl
ARG CURL_VERSION="8.9.0-r0"
# renovate: datasource=repology depName=alpine_3_20/jq
ARG JQ_VERSION="1.7.1-r0"
# renovate: datasource=repology depName=alpine_3_20/docker-cli-compose
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
