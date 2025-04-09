# Multi-arch swarm-launcher image, using docker-compose
FROM public.ecr.aws/docker/library/alpine:3.21.3@sha256:a8560b36e8b8210634f77d9f7f9efd7ffa463e380b75e2e74aff4511df3ef88c

LABEL org.opencontainers.image.authors="swarm-launcher@docker.egos.tech" \
      org.opencontianers.image.description="A docker image to allow the launch of container in docker swarm, with options normally unavailable to swarm mode" \
      org.opencontainers.image.source="https://gitlab.com/ix.ai/swarm-launcher" \
      org.opencontainers.image.url="egos.tech/swarm-launcher"

# renovate: datasource=repology depName=alpine_3_21/bash versioning=loose
ARG BASH_VERSION="5.2.37-r0"
# renovate: datasource=repology depName=alpine_3_21/curl versioning=loose
ARG CURL_VERSION="8.12.1-r1"
# renovate: datasource=repology depName=alpine_3_21/jq versioning=loose
ARG JQ_VERSION="1.7.1-r0"
# renovate: datasource=repology depName=alpine_3_21/docker-cli-compose versioning=loose
ARG DOCKER_CLI_COMPOSE_VERSION="2.31.0-r4"

RUN apk add --no-cache \
    bash="${BASH_VERSION}" \
    curl="${CURL_VERSION}" \
    jq="${JQ_VERSION}" \
    docker-cli-compose="${DOCKER_CLI_COMPOSE_VERSION}"

# add entrypoint.sh launcher script
COPY entrypoint.sh /

# run the image
ENTRYPOINT ["/entrypoint.sh"]
