# official Docker (CLI) image
FROM docker/compose:latest
LABEL maintainer="docker@ix.ai"\
      ai.ix.repository="ix.ai/swarm-launcher"

RUN apk add --no-cache bash

# add entrypoint.sh launcher script
ADD entrypoint.sh /

# run the image
ENTRYPOINT /entrypoint.sh
