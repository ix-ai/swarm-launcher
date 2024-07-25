# Multi-arch docker-compose image
FROM alpine:3.20.2@sha256:0a4eaa0eecf5f8c050e5bba433f58c052be7587ee8af3e8b3910ef9ab5fbe9f5
LABEL maintainer="docker@ix.ai"\
      ai.ix.repository="ix.ai/swarm-launcher"\
      org.opencontianers.image.description="A docker image to allow the launch of container in docker swarm, with options normally unavailable to swarm mode"

RUN apk add --no-cache bash curl jq docker-cli-compose

# add entrypoint.sh launcher script
COPY entrypoint.sh /

# run the image
ENTRYPOINT ["/entrypoint.sh"]
