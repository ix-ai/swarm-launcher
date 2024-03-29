# Multi-arch docker-compose image
FROM alpine:latest
LABEL maintainer="docker@ix.ai"\
      ai.ix.repository="ix.ai/swarm-launcher"\
      org.opencontianers.image.description="A docker image to allow the launch of container in docker swarm, with options normally unavailable to swarm mode"

RUN apk add --no-cache bash curl jq docker-cli-compose

# add entrypoint.sh launcher script
COPY entrypoint.sh /

# run the image
ENTRYPOINT ["/entrypoint.sh"]
