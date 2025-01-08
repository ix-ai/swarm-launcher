# Multi-arch swarm-launcher image, using docker-compose
FROM alpine:3.21.1@sha256:b97e2a89d0b9e4011bb88c02ddf01c544b8c781acf1f4d559e7c8f12f1047ac3

LABEL maintainer="docker@ix.ai" \
      ai.ix.repository="ix.ai/swarm-launcher" \
      org.opencontianers.image.description="A docker image to allow the launch of container in docker swarm, with options normally unavailable to swarm mode" \
      org.opencontainers.image.source="https://gitlab.com/ix.ai/swarm-launcher"

# renovate: datasource=repology depName=alpine_3_21/bash versioning=loose
ARG BASH_VERSION="5.2.37-r0"
# renovate: datasource=repology depName=alpine_3_21/curl versioning=loose
ARG CURL_VERSION="8.11.1-r0"
# renovate: datasource=repology depName=alpine_3_21/jq versioning=loose
ARG JQ_VERSION="1.7.1-r0"
# renovate: datasource=repology depName=alpine_3_21/docker-cli-compose versioning=loose
ARG DOCKER_CLI_COMPOSE_VERSION="2.31.0-r0"

RUN apk add --no-cache \
    bash="${BASH_VERSION}" \
    curl="${CURL_VERSION}" \
    jq="${JQ_VERSION}" \
    docker-cli-compose="${DOCKER_CLI_COMPOSE_VERSION}"

# add entrypoint.sh launcher script
COPY entrypoint.sh /

# run the image
ENTRYPOINT ["/entrypoint.sh"]
